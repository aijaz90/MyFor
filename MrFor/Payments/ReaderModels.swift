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
        // The DynaFlex II Go advertises an abbreviated name like "DF II Go-B5AD44D",
        // so match that too — not just the full "DynaFlex".
        return n.contains("dynaflex") || n.contains("dynaprox") || n.contains("magtek")
            || n.contains("df ii") || n.hasPrefix("df ") || n.contains("dynapro")
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
    let encryptedTrack: String        // hex used for the API's emvSredData
    let ksn: String                   // Key Serial Number (deviceKSN)
    let encryptionMethod: String      // "dukpt"
    let entryMode: CardEntryMode
    var deviceSerialNumber: String = "" // reader serial, from the SDK
    var cardType: String = ""           // e.g. "VISA", derived from track2
    var cardTypeCode: String = ""       // Forte DFDF52 numeric code, e.g. "05"/"06"

    // Full raw read fields — for the debug screen and Swagger testing.
    var transactionType: String = ""   // "EMV" / "MSR"
    var cardHolderName: String = ""
    var maskedTrack2: String = ""       // hex
    var sredData: String = ""           // encrypted card data (from batch)
    var arqcData: String = ""           // full ARQC block hex (AuthorizationRequest)
    var batchData: String = ""          // full batch block hex (TransactionResult)

    /// The reader read as pretty JSON (same shape as the Android app dumps),
    /// for the "Copy all" action on the debug screen.
    var debugJSON: String {
        let dict: [String: Any] = [
            "transactionType": transactionType,
            "deviceKSN": ksn,
            "deviceSerialNumber": deviceSerialNumber,
            "cardType": cardType,
            "cardHolderName": cardHolderName,
            "maskTrack2": maskedTrack2,
            "sredData": sredData,
            "arqcData": arqcData,
            "batchData": batchData,
        ]
        guard JSONSerialization.isValidJSONObject(dict),
              let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return "" }
        return json
    }

    /// The full reader read as a dictionary, for logging to `AppLogger`
    /// (Firestore + local mirror). These fields are already DUKPT-encrypted
    /// ciphertext (KSN/ARQC/SRED/batch/track) or non-sensitive metadata —
    /// never a plaintext PAN — so it's safe to log in full for remote
    /// debugging, unlike raw card numbers/CVV/PIN.
    var loggableDict: [String: Any] {
        [
            "entryMode": entryMode.rawValue,
            "encryptionMethod": encryptionMethod,
            "transactionType": transactionType,
            "deviceKSN": ksn,
            "deviceSerialNumber": deviceSerialNumber,
            "cardType": cardType,
            "cardHolderName": cardHolderName,
            "maskTrack2": maskedTrack2,
            "encryptedTrack": encryptedTrack,
            "sredData": sredData,
            "arqcData": arqcData,
            "batchData": batchData,
        ]
    }
}

/// Outcome of reading a card from the physical reader (before charging).
enum ReaderReadResult {
    case success(EncryptedCardData)
    case failed(String)
}

/// The one surface the UI depends on. Both engines conform, guaranteeing parity.
@MainActor
protocol ReaderEngineProtocol: AnyObject {
    var devices: [ReaderDevice] { get }
    var connectionState: ReaderConnectionState { get }
    var isReady: Bool { get }            // Bluetooth powered on / SDK ready
    var connectedName: String? { get }
    var statusMessage: String? { get }   // live prompts during a read ("PRESENT CARD")

    func start()                          // begin discovery
    func stop()                           // end discovery
    func connect(_ device: ReaderDevice)
    func disconnect()

    /// Drive the reader to produce one encrypted card read. The caller (the
    /// view model) sends the result to the payment API.
    func readCard(amount: Decimal) async -> ReaderReadResult
}

// MARK: - Compile-time engine selection

#if canImport(MTUSDK)
typealias ReaderEngine = MagTekReader
#else
typealias ReaderEngine = BluetoothManager
#endif
