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
    // Raw blocks accumulated across events during one read.
    @ObservationIgnored private var capturedArqcHex = ""
    @ObservationIgnored private var capturedBatchHex = ""

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
            AppLogger.shared.guardFailure("connect: no IDevice for id", data: ["deviceId": device.id])
            return
        }
        stop()
        self.device = idevice
        connectionState = .connecting(device.id)
        connectedName = idevice.deviceName
        MTLog("🔗 Connecting to \(idevice.deviceName)…")
        AppLogger.shared.reader("Connecting to reader", data: ["deviceName": idevice.deviceName])
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
            AppLogger.shared.reader("Disconnected from reader", data: ["deviceName": device.deviceName])
        }
        device = nil
        connectedName = nil
        connectionState = .idle
    }

    // MARK: Read — start a QuickChip transaction and return the encrypted read

    func readCard(amount: Decimal) async -> ReaderReadResult {
        guard let device else {
            return .failed("No reader connected. Open Bluetooth and connect the DynaFlex II Go first.")
        }

        let transaction = ITransaction.amount(
            amountString(amount),
            cashback: "0.00",
            transactionType: 0,                       // 0x00 = purchase (EMV 9C)
            timeout: 60,
            for: [.MSR, .contact, .contactless],
            quickChip: true                           // defer approval to the processor
        )
        transaction.currencyCode = Data([0x08, 0x40])   // USD (ISO 4217 numeric 840)

        capturedArqcHex = ""
        capturedBatchHex = ""
        MTLog("🟢 Read started: amount=\(amountString(amount)) — present card")
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
            MTLog("💳 Card read OK (\(card.entryMode.rawValue), \(card.encryptedTrack.count / 2) bytes, ksn=\(card.ksn.isEmpty ? "none" : "present"))")
            return .success(card)
        } catch let SaleError.declined(m) {
            MTLog("🚫 Read declined by reader: \(m)"); return .failed(m)
        } catch SaleError.cancelled {
            MTLog("🟡 Read cancelled"); return .failed("Transaction cancelled.")
        } catch SaleError.timeout {
            MTLog("⏱️ Read timed out (no card presented)"); return .failed("Card was not presented in time.")
        } catch let SaleError.failed(m) {
            MTLog("❌ Read failed: \(m)"); return .failed(m)
        } catch {
            MTLog("❌ Read error: \(error.localizedDescription)"); return .failed(error.localizedDescription)
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
            AppLogger.shared.reader("Reader connected", data: ["deviceName": device.deviceName])
        case MTU_ConnectionState_Disconnected:
            connectionState = .idle
            connectedName = nil
            MTLog("🔌 Reader disconnected")
            AppLogger.shared.reader("Reader disconnected")
        case MTU_ConnectionState_Error:
            connectionState = .failed("Reader connection error.")
            MTLog("❌ Reader connection error")
            AppLogger.shared.error("Reader connection error")
        default:
            break
        }
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
                    // MSR swipe — self-contained, no separate batch block.
                    MTLog("🪪 CardData (MSR swipe) received")
                    self.entryMode = .swipe
                    self.capturedArqcHex = self.hexString(from: data)
                    self.finishRead()

                case MTU_EventType_AuthorizationRequest:
                    // EMV chip/contactless ARQC block. Capture it, but wait for the
                    // TransactionResult (batch) which carries the SRED card data.
                    MTLog("🔐 AuthorizationRequest (ARQC) received")
                    self.capturedArqcHex = self.hexString(from: data)

                case MTU_EventType_TransactionResult:
                    // Batch/clearing block — carries the encrypted SRED card data.
                    MTLog("🧾 TransactionResult (batch) received — card read complete")
                    self.capturedBatchHex = self.hexString(from: data)
                    self.finishRead()

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
        case MTU_TransactionStatus_TransactionCompleted, MTU_TransactionStatus_TransactionApproved,
             MTU_TransactionStatus_QuickChipDeferred:
            // Fallback: if we captured the ARQC but never saw a TransactionResult,
            // finish with what we have so the read still returns.
            if !capturedArqcHex.isEmpty { finishRead() }
        default:
            break
        }
    }

    /// Build the full read from the accumulated blocks and resume the read.
    private func finishRead() {
        guard saleContinuation != nil else { return }   // already finished
        finishSale(.success(buildReadData()))
    }

    /// Parse the raw ARQC/batch blocks into the full read fields.
    private func buildReadData() -> EncryptedCardData {
        let arqc = Data(hex: capturedArqcHex)
        let batch = Data(hex: capturedBatchHex)

        let ksn = TLV.value(tag: [0xDF, 0xDF, 0x54], in: arqc)
            ?? TLV.value(tag: [0xDF, 0xDF, 0x54], in: batch) ?? ""
        let track2 = TLV.value(tag: [0xDF, 0xDF, 0x4D], in: arqc)
            ?? TLV.value(tag: [0xDF, 0xDF, 0x4D], in: batch) ?? ""
        // Encrypted card data (SRED) lives in the batch block's DFDF59.
        let sred = TLV.value(tag: [0xDF, 0xDF, 0x59], in: batch) ?? ""
        let serialHex = TLV.value(tag: [0xDF, 0xDF, 0x25], in: arqc)
            ?? TLV.value(tag: [0xDF, 0xDF, 0x25], in: batch) ?? ""
        let serial = Data(hex: serialHex).asciiString
            ?? (device?.getInfo()?.deviceSerialNumber ?? "")
        let holder = TLV.value(tag: [0x5F, 0x20], in: arqc).flatMap { Data(hex: $0).asciiString } ?? ""

        return EncryptedCardData(
            encryptedTrack: sred.isEmpty ? capturedArqcHex : sred,   // API emvSredData
            ksn: ksn,
            encryptionMethod: "dukpt",
            entryMode: entryMode,
            deviceSerialNumber: serial,
            cardType: Self.cardType(fromTrack2Hex: track2),
            transactionType: entryMode == .swipe ? "MSR" : "EMV", // find for insert type
            cardHolderName: holder,
            maskedTrack2: track2,
            sredData: sred,
            arqcData: capturedArqcHex,
            batchData: capturedBatchHex
        )
    }

    private func hexString(from data: IData?) -> String {
        guard let bytes = data?.byteArray as Data? else { return "" }
        return bytes.map { String(format: "%02X", $0) }.joined()
    }

    /// Brand from the track-2 PAN (first digit): hex track2 → ASCII → PAN.
    private static func cardType(fromTrack2Hex hex: String) -> String {
        guard let track = Data(hex: hex).asciiString else { return "" }
        let digits = track.drop { !$0.isNumber }               // skip leading ';'
        let pan = String(digits.prefix { $0 != "=" && $0 != "D" })
        guard let first = pan.first else { return "" }
        switch first {
        case "4": return "VISA"
        case "5", "2": return "MASTERCARD"
        case "3": return "AMEX"
        case "6": return "DISCOVER"
        default: return ""
        }
    }
}

/// Scans a byte buffer for a BER-TLV tag (tolerant of length prefixes on the
/// event data) and returns its value as hex. Robust enough to pull specific tags
/// (KSN, track2, SRED, serial) out of the ARQC/batch blocks.
private enum TLV {
    static func value(tag: [UInt8], in data: Data) -> String? {
        let b = [UInt8](data)
        guard !tag.isEmpty, b.count > tag.count else { return nil }
        var i = 0
        while i + tag.count <= b.count {
            if Array(b[i..<i + tag.count]) == tag {
                var j = i + tag.count
                guard j < b.count else { return nil }
                var len = Int(b[j]); j += 1
                if len & 0x80 != 0 {
                    let n = len & 0x7F
                    if n < 1 || n > 3 || j + n > b.count { i += 1; continue }
                    len = 0
                    for _ in 0..<n { len = (len << 8) | Int(b[j]); j += 1 }
                }
                if j + len <= b.count {
                    return b[j..<j + len].map { String(format: "%02X", $0) }.joined()
                }
            }
            i += 1
        }
        return nil
    }
}

private extension Data {
    /// Build Data from a hex string (ignores non-hex chars). Empty for empty input.
    init(hex: String) {
        let chars = hex.filter { $0.isHexDigit }
        var bytes = [UInt8]()
        bytes.reserveCapacity(chars.count / 2)
        var idx = chars.startIndex
        while idx < chars.endIndex, chars.index(after: idx) < chars.endIndex {
            let next = chars.index(idx, offsetBy: 2)
            if let byte = UInt8(chars[idx..<next], radix: 16) { bytes.append(byte) }
            idx = next
        }
        self = Data(bytes)
    }

    /// Printable ASCII interpretation, or nil if it isn't printable text.
    var asciiString: String? {
        guard !isEmpty, let s = String(data: self, encoding: .ascii),
              s.allSatisfy({ $0.isASCII }) else { return nil }
        return s
    }
}

#endif
