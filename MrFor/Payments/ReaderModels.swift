//
//  ReaderModels.swift
//  MrFor
//
//  Shared types + the compile-time seam that swaps reader engines.
//
//  The MagTek Universal SDK owns Bluetooth discovery and connection itself, so
//  we must NOT also run a CoreBluetooth stack against the same reader. Instead
//  both engines expose one surface (ReaderEngineProtocol) and a typealias picks
//  the concrete one:
//
//    • MTUSDK linked  → MagTekReader   (real DynaFlex II Go transactions)
//    • MTUSDK absent  → BluetoothManager (CoreBluetooth: shows/does the device
//                        list + green/red, but a sale reports "add the SDK")
//
//  The UI binds to `ReaderEngine`, so it never changes between the two builds.
//

import Foundation

/// Lightweight console logging for the payment/reader flow, visible in Xcode.
/// DEBUG-only so a release build never logs card-flow details. Never pass raw
/// card data here — log lengths/status only.
func MTLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print("💳 MrFor › \(message())")
    #endif
}

/// Pretty-prints the reader's card-read output as JSON, so it's easy to inspect
/// (or copy) in the Xcode console. DEBUG-only.
///
/// `encryptedTrack` here is DUKPT ciphertext, never a plaintext PAN — the app
/// has no key to decrypt it, only Forte/Magensa does downstream. It's still
/// only logged in DEBUG builds, same as everything else that touches card data.
func logCardData(_ card: EncryptedCardData) {
    #if DEBUG
    let dict: [String: Any] = [
        "entryMode": card.entryMode.rawValue,
        "encryptionMethod": card.encryptionMethod,
        "ksn": card.ksn.isEmpty ? "" : card.ksn,
        "encryptedTrack": card.encryptedTrack,
    ]
    var text = "\n💳 CARD READ (from reader)"
    if JSONSerialization.isValidJSONObject(dict),
       let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
       let json = String(data: data, encoding: .utf8) {
        text += "\n\(json)"
    }
    print(text)
    #endif
}

/// A reader shown in the device list. Engine-agnostic: the concrete engine keeps
/// its own handle (CBPeripheral / IDevice) in a private table keyed by `id`.
struct ReaderDevice: Identifiable, Equatable {
    let id: String
    let name: String
    var rssi: Int?

    var isLikelyReader: Bool {
        let n = name.lowercased()
        return n.contains("dynaflex") || n.contains("dynaprox") || n.contains("magtek")
    }
}

enum ReaderConnectionState: Equatable {
    case idle
    case scanning
    case connecting(String)
    case connected(String)
    case failed(String)

    var isConnected: Bool { if case .connected = self { return true } else { return false } }
}

/// How the card was read, so the backend/Forte knows the entry mode.
enum CardEntryMode: String {
    case chip
    case contactless
    case swipe
    case manual
}

/// The encrypted output of one card read. Never contains a plaintext PAN.
/// For EMV chip/contactless this carries the ARQC + EMV tag block that MagTek
/// says is "meant to be sent to the transaction processor". For MSR it carries
/// the encrypted MagneSafe swipe.
struct EncryptedCardData {
    let encryptedTrack: String   // hex of the ARQC/EMV TLV block or encrypted MSR
    let ksn: String              // Key Serial Number, if parsed out
    let encryptionMethod: String // "dukpt"
    let entryMode: CardEntryMode
}

/// The one surface the UI depends on. Both engines conform, guaranteeing parity.
@MainActor
protocol ReaderEngineProtocol: AnyObject {
    var devices: [ReaderDevice] { get }
    var connectionState: ReaderConnectionState { get }
    var isReady: Bool { get }            // Bluetooth powered on / SDK ready
    var connectedName: String? { get }
    var statusMessage: String? { get }   // live prompts during a sale ("PRESENT CARD")

    func start()                          // begin discovery
    func stop()                           // end discovery
    func connect(_ device: ReaderDevice)
    func disconnect()

    /// Read a card off the connected reader and charge it via the Forte backend.
    func runSale(amount: Decimal, orderNumber: String?) async -> PaymentOutcome
}

// MARK: - Compile-time engine selection

#if canImport(MTUSDK)
typealias ReaderEngine = MagTekReader
#else
typealias ReaderEngine = BluetoothManager
#endif
