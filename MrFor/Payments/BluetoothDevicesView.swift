//
//  BluetoothDevicesView.swift
//  MrFor
//
//  The "Bluetooth section" opened from the payment screen. Shows discovered
//  readers, lets the user tap the DynaFlex II Go to connect, and reflects state.
//  Binds to `ReaderEngine`, which is the MagTek SDK engine when linked, else the
//  CoreBluetooth fallback — the UI is the same either way.
//

import SwiftUI

struct BluetoothDevicesView: View {
    let reader: ReaderEngine
    @Environment(\.dismiss) private var dismiss

    /// Debug read amount — value is irrelevant, we only want the reader's data.
    private let readAmount: Decimal = 1.00

    @State private var reading = false
    @State private var readItem: ReadResultItem?
    @State private var readError: String?

    private struct ReadResultItem: Identifiable { let id = UUID(); let data: EncryptedCardData }

    var body: some View {
        NavigationStack {
            List {
                Section("Reader") { statusRow }

                Section("Available devices") {
                    if reader.devices.isEmpty {
                        HStack {
                            if case .scanning = reader.connectionState { ProgressView().padding(.trailing, 4) }
                            Text(reader.isReady ? "Searching for devices…" : "Turn on Bluetooth to search.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(reader.devices) { device in deviceRow(device) }
                    }
                }
            }
            .navigationTitle("Bluetooth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if case .scanning = reader.connectionState {
                        Button("Stop") { reader.stop() }
                    } else {
                        Button("Scan") { reader.start() }.disabled(!reader.isReady)
                    }
                }
            }
            // "Tap to Pay" bar pinned to the bottom once a reader is connected.
            .safeAreaInset(edge: .bottom) {
                if reader.connectionState.isConnected { tapToPayBar }
            }
            .sheet(item: $readItem) { item in
                ReaderDataView(data: item.data) { readItem = nil }
            }
            .alert("Read failed", isPresented: Binding(get: { readError != nil }, set: { if !$0 { readError = nil } })) {
                Button("OK", role: .cancel) { readError = nil }
            } message: {
                Text(readError ?? "")
            }
            .onAppear {
                AppLogger.shared.screen("BluetoothDevicesView")
                if reader.isReady { reader.start() }
            }
            .onDisappear { if !reading { reader.stop() } }
        }
    }

    // MARK: Tap to Pay

    private var tapToPayBar: some View {
        VStack(spacing: 8) {
            if reading, let prompt = reader.statusMessage, !prompt.isEmpty {
                Text(prompt).font(.footnote.weight(.medium)).foregroundStyle(.secondary)
            }
            Button {
                Task { await readCard() }
            } label: {
                HStack(spacing: 8) {
                    if reading { ProgressView().padding(.trailing, 2) }
                    Image(systemName: "creditcard.wireless")
                    Text(reading ? "Present card…" : "Verify · Tap to Pay")
                }
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(reading)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func readCard() async {
        reading = true
        defer { reading = false }
        let result = await reader.readCard(amount: readAmount)
        switch result {
        case .success(let data):
            AppLogger.shared.reader("Card read OK (debug/verify)", data: data.loggableDict)
            readItem = ReadResultItem(data: data)
        case .failed(let message):
            AppLogger.shared.error("Card read failed (debug/verify)", data: ["message": message])
            readError = message
        }
    }

    private var statusRow: some View {
        HStack {
            Circle()
                .fill(reader.connectionState.isConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle).font(.subheadline.weight(.medium))
                if reader.connectionState.isConnected, let name = reader.connectedName {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if reader.connectionState.isConnected {
                Button("Disconnect", role: .destructive) { reader.disconnect() }
                    .buttonStyle(.borderless)
            }
        }
    }

    private func deviceRow(_ device: ReaderDevice) -> some View {
        Button {
            reader.connect(device)
        } label: {
            HStack {
                Image(systemName: device.isLikelyReader ? "creditcard.wireless" : "dot.radiowaves.left.and.right")
                    .foregroundStyle(device.isLikelyReader ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name).foregroundStyle(.primary)
                    if let rssi = device.rssi {
                        Text(signalLabel(rssi)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                connectionAccessory(for: device)
            }
        }
    }

    @ViewBuilder
    private func connectionAccessory(for device: ReaderDevice) -> some View {
        switch reader.connectionState {
        case .connecting(let id) where id == device.id:
            ProgressView()
        case .connected(let id) where id == device.id:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        default:
            EmptyView()
        }
    }

    private var statusTitle: String {
        switch reader.connectionState {
        case .connected: return "Connected"
        case .connecting: return "Connecting…"
        case .scanning: return "Scanning…"
        case .failed(let m): return m
        case .idle: return reader.isReady ? "Not connected" : "Bluetooth off"
        }
    }

    private func signalLabel(_ rssi: Int) -> String {
        let strength = rssi > -55 ? "Strong" : rssi > -75 ? "Good" : "Weak"
        return "\(strength) signal · \(rssi) dBm"
    }
}
