//
//  MagTekReader.swift
//  MrFor
//
//  The real reader engine: MagTek Universal SDK (MTUSDK) driving a DynaFlex II Go.
//  Compiled only when the framework is linked (see ReaderModels.swift seam).
//
//  Written against the actual MTUSDK headers and MagTek's sample app (verified
//  Swift symbol names), not just the manual. Flow:
//    setDeviceType(MMS, BLE_EMV) → startDiscover() → onDeviceList (delegate)
//    → getDeviceControl().open() to connect → subscribeAll(self)
//    → start(ITransaction.amount(... quickChip:true)) → onEvent(...) events
//    → AuthorizationRequest carries the encrypted ARQC block for the processor.
//
//  We deliberately do NOT decrypt locally (the sample's MTEncryptedData path uses
//  a test BDK key). The encrypted bytes go to our backend → Forte → Magensa.
//

#if canImport(MTUSDK)

import Foundation
// MTUSDK is an Objective-C module with no Swift concurrency annotations, so its
// types (IData, IDevice) aren't marked Sendable. @preconcurrency silences the
// resulting Sendable warnings when we hand those objects across the main-queue
// hop in the delegate callbacks — behavior is unchanged.
@preconcurrency import MTUSDK

@MainActor
@Observable
final class MagTekReader: NSObject, ReaderEngineProtocol {

    /// BLE (wireless; pair the reader first — hold power to 4 beeps, code 000000)
    /// or USB-C (iAP2; needs `com.magtek.dynaflex2go` in the app's EA protocols).
    enum Link { case bluetoothLE, usbC }
    var link: Link = .bluetoothLE

    // MARK: ReaderEngineProtocol state
    private(set) var devices: [ReaderDevice] = []
    private(set) var connectionState: ReaderConnectionState = .idle
    private(set) var isReady = true          // SDK manages BLE power; refined by didSystemUpdate
    private(set) var connectedName: String?
    private(set) var statusMessage: String?

    // MARK: SDK handles
    @ObservationIgnored private let core = CoreAPI.shared()
    @ObservationIgnored private var deviceTable: [String: IDevice] = [:]
    @ObservationIgnored private var device: IDevice?

    // MARK: Sale bridging (event-driven → async)
    @ObservationIgnored private var saleContinuation: CheckedContinuation<EncryptedCardData, Error>?
    @ObservationIgnored private var entryMode: CardEntryMode = .chip

    private enum SaleError: Error { case declined(String), cancelled, timeout, failed(String) }

    override init() {
        super.init()
        core.mtuSDKDelegate = self
        MTLog("MagTek engine ready (SDK linked)")
    }

    // MARK: Discovery

    func start() {
        deviceTable.removeAll()
        devices.removeAll()
        connectionState = .scanning
        switch link {
        case .bluetoothLE:
            core.setDeviceType(MTU_DeviceType_MMS, andConnectionType: MTU_ConnectionType_BLUETOOTH_LE_EMV)
        case .usbC:
            core.setDeviceType(MTU_DeviceType_MMS, andConnectionType: MTU_ConnectionType_EXTERNAL_ACCESSORY)
            core.setupEADeviceProtocolString("com.magtek.dynaflex2go")
        }
        core.startDiscover()
        MTLog("🔍 Discovery started (link: \(link == .bluetoothLE ? "BLE" : "USB-C"))")
    }

    func stop() {
        core.stopDiscover()
        if case .scanning = connectionState { connectionState = .idle }
        MTLog("🔍 Discovery stopped")
    }

    func connect(_ device: ReaderDevice) {
        guard let idevice = deviceTable[device.id] else {
            MTLog("⚠️ connect: no IDevice for id \(device.id)")
            return
        }
        stop()
        self.device = idevice
        connectionState = .connecting(device.id)
        connectedName = idevice.deviceName
        MTLog("🔗 Connecting to \(idevice.deviceName)…")
        let subscribed = idevice.subscribeAll(self)
        // Opening the control interface establishes the connection; ConnectionState
        // events (see onEvent) then move us to .connected.
        let opened = idevice.getControl()?.open() ?? false
        MTLog("🔗 subscribeAll=\(subscribed) open=\(opened)")
    }

    func disconnect() {
        if let device {
            _ = device.unsubscribeAll(self)
            _ = device.getControl()?.close()
            MTLog("🔌 Disconnected from \(device.deviceName)")
        }
        device = nil
        connectedName = nil
        connectionState = .idle
    }

    // MARK: Sale — start a QuickChip transaction and await the encrypted read

    func runSale(amount: Decimal, orderNumber: String?) async -> PaymentOutcome {
        guard let device else {
            return .failed(message: "No reader connected. Open Bluetooth and connect the DynaFlex II Go first.")
        }

        let transaction = ITransaction.amount(
            amountString(amount),
            cashback: "0.00",
            transactionType: 0,                       // 0x00 = purchase (EMV 9C)
            timeout: 60,
            for: [.MSR, .contact, .contactless],
            quickChip: true                           // defer approval to Forte
        )
        transaction.currencyCode = Data([0x08, 0x40])   // USD (ISO 4217 numeric 840)

        MTLog("🟢 Sale started: amount=\(amountString(amount)) order=\(orderNumber ?? "-") — present card")
        do {
            let card: EncryptedCardData = try await withCheckedThrowingContinuation { cont in
                self.saleContinuation = cont
                if !device.start(transaction) {
                    self.saleContinuation = nil
                    MTLog("❌ Reader refused to start the transaction")
                    cont.resume(throwing: SaleError.failed("The reader did not start the transaction."))
                }
            }
            statusMessage = nil
            logCardData(card)
            MTLog("💳 Card read OK (\(card.entryMode.rawValue), \(card.encryptedTrack.count / 2) bytes, ksn=\(card.ksn.isEmpty ? "none" : "present")) → sending to backend")
            let outcome = await PaymentAPIClient.cardPresentSale(amount: amount, orderNumber: orderNumber, swipe: card)
            MTLog("🏦 Backend result: \(outcome)")
            return outcome
        } catch let SaleError.declined(m) {
            MTLog("🚫 Sale declined by reader: \(m)")
            return .declined(message: m)
        } catch SaleError.cancelled {
            MTLog("🟡 Sale cancelled")
            return .failed(message: "Transaction cancelled.")
        } catch SaleError.timeout {
            MTLog("⏱️ Sale timed out (no card presented)")
            return .failed(message: "Card was not presented in time.")
        } catch let SaleError.failed(m) {
            MTLog("❌ Sale failed: \(m)")
            return .failed(message: m)
        } catch {
            MTLog("❌ Sale error: \(error.localizedDescription)")
            return .failed(message: error.localizedDescription)
        }
    }

    private func finishSale(_ result: Result<EncryptedCardData, Error>) {
        guard let cont = saleContinuation else { return }
        saleContinuation = nil
        cont.resume(with: result)
    }

    // MARK: Helpers

    private func amountString(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).description   // 25.00 -> "25", 12.5 -> "12.5"
    }

    private func refreshConnected() {
        guard let device else { return }
        switch device.getConnectionState() {
        case MTU_ConnectionState_Connected:
            connectionState = .connected(device.deviceName)
            connectedName = device.deviceName
            MTLog("✅ Connected to \(device.deviceName)")
        case MTU_ConnectionState_Disconnected:
            connectionState = .idle
            connectedName = nil
            MTLog("🔌 Reader disconnected")
        case MTU_ConnectionState_Error:
            connectionState = .failed("Reader connection error.")
            MTLog("❌ Reader connection error")
        default:
            break
        }
    }

    /// Build EncryptedCardData from an event payload. KSN (if present) is BER-TLV
    /// tag DFDF50 in MagTek's encrypted output; we still forward the whole block.
    private func makeCardData(from data: IData?) -> EncryptedCardData {
        let bytes = (data?.byteArray as Data?) ?? Data()
        let hex = bytes.map { String(format: "%02X", $0) }.joined()
        let ksn = TLV.firstValueHex(tag: [0xDF, 0xDF, 0x50], in: bytes) ?? ""
        return EncryptedCardData(encryptedTrack: hex, ksn: ksn, encryptionMethod: "dukpt", entryMode: entryMode)
    }
}

// MARK: - MTUSDKDelegate (discovery). SDK delivers these on the main queue.

extension MagTekReader: MTUSDKDelegate {
    nonisolated func onDeviceList(_ instance: Any, with connectionType: MTU_ConnectionType, deviceList: [IDevice]) {
        // The SDK may deliver this off the main thread, so hop to main before
        // touching @MainActor state (assumeIsolated would trap otherwise).
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.deviceTable.removeAll()
                var list: [ReaderDevice] = []
                for idevice in deviceList {
                    let name = idevice.deviceName
                    self.deviceTable[name] = idevice
                    list.append(ReaderDevice(id: name, name: name, rssi: nil))
                }
                list.sort { $0.isLikelyReader && !$1.isLikelyReader }
                self.devices = list
                MTLog("📡 Found \(list.count) device(s): \(list.map { $0.name }.joined(separator: ", "))")
            }
        }
    }

    nonisolated func didSystemUpdate(_ state: SystemState) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                switch state {
                case .bluetoothLEPoweredOn:
                    self.isReady = true
                    MTLog("📶 Bluetooth powered on")
                case .bluetoothLEPoweredOff, .bluetoothLEUnsupported:
                    self.isReady = false
                    self.connectionState = .failed("Bluetooth is off.")
                    MTLog("📵 Bluetooth off/unsupported")
                case .bluetoothLEUnauthorized:
                    self.isReady = false
                    self.connectionState = .failed("Bluetooth permission denied. Enable it in Settings.")
                    MTLog("🚫 Bluetooth permission denied")
                default:
                    break
                }
            }
        }
    }
}

// MARK: - IEventSubscriber (transaction events). Delivered on the main queue.

extension MagTekReader: IEventSubscriber {
    nonisolated func onEvent(_ eventType: MTU_EventType, data: IData!) {
        // Delivered on a background thread in practice; hop to main to keep event
        // order (FIFO) and touch @MainActor state safely.
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                switch eventType {

                case MTU_EventType_ConnectionState:
                    self.refreshConnected()

                case MTU_EventType_DisplayMessage:
                    let msg = data?.stringValue ?? ""
                    self.statusMessage = msg.isEmpty ? nil : msg   // empty = clear display
                    if !msg.isEmpty { MTLog("💬 Reader: \(msg)") }

                case MTU_EventType_ClearDisplay:
                    self.statusMessage = nil

                case MTU_EventType_InputRequest:
                    // App/language selection. Auto-confirm the default: status 0x00, item 0x00.
                    MTLog("⌨️ Input request → auto-selecting default")
                    _ = self.device?.sendSelection(IData(hex: "0001"))

                case MTU_EventType_TransactionStatus:
                    let status = TransactionStatusBuilder.getStatusCode(data?.stringValue ?? "")
                    MTLog("📊 Transaction status: \(status.rawValue)")
                    self.handleTransactionStatus(status)

                case MTU_EventType_CardData:
                    MTLog("🪪 CardData (MSR swipe) received")
                    self.entryMode = .swipe
                    self.finishSale(.success(self.makeCardData(from: data)))

                case MTU_EventType_AuthorizationRequest:
                    // EMV chip/contactless ARQC + tag block for the processor.
                    MTLog("🔐 AuthorizationRequest (ARQC) received — encrypted card captured")
                    self.finishSale(.success(self.makeCardData(from: data)))

                default:
                    break
                }
            }
        }
    }

    private func handleTransactionStatus(_ status: MTU_TransactionStatus) {
        switch status {
        case MTU_TransactionStatus_CardInserted:
            entryMode = .chip
        case MTU_TransactionStatus_CardSwiped, MTU_TransactionStatus_MSRFallback:
            entryMode = .swipe
        case MTU_TransactionStatus_TimedOut:
            finishSale(.failure(SaleError.timeout))
        case MTU_TransactionStatus_HostCancelled, MTU_TransactionStatus_TransactionCancelled:
            finishSale(.failure(SaleError.cancelled))
        case MTU_TransactionStatus_TransactionDeclined:
            finishSale(.failure(SaleError.declined("The reader declined the card.")))
        case MTU_TransactionStatus_TransactionError, MTU_TransactionStatus_TransactionFailed,
             MTU_TransactionStatus_TransactionNotAccepted:
            finishSale(.failure(SaleError.failed("The transaction could not be completed on the reader.")))
        default:
            break
        }
    }
}

/// Minimal BER-TLV walker: first value (hex) for a multi-byte tag. Pulls the KSN.
private enum TLV {
    static func firstValueHex(tag: [UInt8], in data: Data) -> String? {
        let b = [UInt8](data)
        var i = 0
        while i < b.count {
            var tagBytes: [UInt8] = [b[i]]
            if b[i] & 0x1F == 0x1F {
                repeat { i += 1; if i >= b.count { return nil }; tagBytes.append(b[i]) }
                while b[i] & 0x80 == 0x80
            }
            i += 1
            if i >= b.count { return nil }
            var len = Int(b[i]); i += 1
            if len & 0x80 != 0 {
                let n = len & 0x7F
                len = 0
                for _ in 0..<n { if i >= b.count { return nil }; len = (len << 8) | Int(b[i]); i += 1 }
            }
            if i + len > b.count { return nil }
            if tagBytes == tag {
                return b[i..<i+len].map { String(format: "%02X", $0) }.joined()
            }
            i += len
        }
        return nil
    }
}

#endif
