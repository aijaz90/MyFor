//
//  BluetoothManager.swift
//  MrFor
//
//  The FALLBACK reader engine, used only when the MagTek SDK is NOT linked.
//  It uses CoreBluetooth to show a real device list and connection state
//  (green/red), which is a useful hardware sanity check, but it cannot run a
//  card transaction — that needs MagTek's SDK. `runSale` says so plainly.
//
//  When MTUSDK.xcframework is added, ReaderEngine becomes MagTekReader instead
//  and this file is no longer used at runtime (see ReaderModels.swift).
//
//  Note: CoreBluetooth does nothing on the iOS Simulator. Test on a device.
//

import Foundation
import CoreBluetooth

@MainActor
@Observable
final class BluetoothManager: NSObject, ReaderEngineProtocol {
    private(set) var devices: [ReaderDevice] = []
    private(set) var connectionState: ReaderConnectionState = .idle
    private(set) var isReady = false
    private(set) var connectedName: String?
    private(set) var statusMessage: String?

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripherals: [String: CBPeripheral] = [:]
    @ObservationIgnored private var connected: CBPeripheral?
    @ObservationIgnored private var autoReconnecting = false
    @ObservationIgnored private var autoReconnectTimeout: Task<Void, Never>?
    private static let savedReaderKey = "mrfor.saved_reader_id"
    private var savedReaderId: String? {
        get { UserDefaults.standard.string(forKey: Self.savedReaderKey) }
        set { UserDefaults.standard.setValue(newValue, forKey: Self.savedReaderKey) }
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: ReaderEngineProtocol

    func start() {
        guard isReady, let central else { return }
        devices.removeAll()
        peripherals.removeAll()
        connectionState = .scanning
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stop() {
        central?.stopScan()
        if case .scanning = connectionState { connectionState = .idle }
    }

    /// Silently retry connecting to the last-paired reader by name. CoreBluetooth
    /// can't reconnect by identifier across launches reliably without retrieving
    /// known peripherals, so we scan and match by saved name, same UX as MagTek's
    /// auto-reconnect (pill shows "Scanning…" instead of a bare "No reader").
    func reconnectIfNeeded() {
        guard let saved = savedReaderId, !connectionState.isConnected, !autoReconnecting, isReady else { return }
        autoReconnecting = true
        connectionState = .scanning
        start()
        autoReconnectTimeout?.cancel()
        autoReconnectTimeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            await MainActor.run {
                guard let self, self.autoReconnecting else { return }
                self.autoReconnecting = false
                if case .scanning = self.connectionState { self.stop() }
            }
        }
        MTLog("🔁 Auto-reconnect (fallback): scanning for \(saved)…")
    }

    func connect(_ device: ReaderDevice) {
        guard let peripheral = peripherals[device.id], let central else { return }
        stop()
        connectionState = .connecting(device.id)
        connected = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        savedReaderId = device.id
    }

    func disconnect() {
        savedReaderId = nil
        autoReconnecting = false
        autoReconnectTimeout?.cancel()
        if let p = connected { central?.cancelPeripheralConnection(p) }
    }

    func readCard(amount: Decimal) async -> ReaderReadResult {
        .failed("Card reading needs MagTek's SDK. Add MTUSDK.xcframework + MTSCRA.xcframework to the MrFor target, then rebuild — the app will switch to the real reader automatically.")
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let on = central.state == .poweredOn
        let unauthorized = central.state == .unauthorized
        Task { @MainActor in
            self.isReady = on
            if !on {
                self.devices.removeAll()
                self.connectionState = unauthorized
                    ? .failed("Bluetooth permission denied. Enable it in Settings.")
                    : .idle
            } else {
                self.reconnectIfNeeded()
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advName ?? peripheral.name ?? ""
        guard !name.isEmpty else { return }
        let id = peripheral.identifier.uuidString
        let rssi = RSSI.intValue

        Task { @MainActor in
            self.peripherals[id] = peripheral
            if let idx = self.devices.firstIndex(where: { $0.id == id }) {
                self.devices[idx].rssi = rssi
            } else {
                self.devices.append(ReaderDevice(id: id, name: name, rssi: rssi))
            }
            self.devices.sort {
                $0.isLikelyReader != $1.isLikelyReader ? $0.isLikelyReader : ($0.rssi ?? -999) > ($1.rssi ?? -999)
            }
            // Auto-reconnect: if the previously-paired reader just showed up
            // while we're scanning for it, connect immediately.
            if self.autoReconnecting, self.savedReaderId == id {
                self.autoReconnecting = false
                self.autoReconnectTimeout?.cancel()
                self.connect(ReaderDevice(id: id, name: name, rssi: rssi))
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let id = peripheral.identifier.uuidString
        let name = peripheral.name
        Task { @MainActor in
            self.connectionState = .connected(id)
            self.connectedName = name
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let message = error?.localizedDescription ?? "Could not connect."
        Task { @MainActor in self.connectionState = .failed(message) }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.connectedName = nil
            self.connected = nil
            self.connectionState = .idle
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {}
