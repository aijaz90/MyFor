//
//  CardReaderBridge.swift
//  MrFor
//
//  ── Read this before writing any Bluetooth code. ──────────────────────────
//
//  Hardware: MagTek DynaFlex II Go. USB-C + Bluetooth LE. EMV contact chip,
//  EMV contactless/NFC (incl. Apple Pay), and magstripe. Encrypts under
//  TDEA/AES DUKPT.
//
//  Three facts constrain the design, in descending order of importance:
//
//  1. A WKWebView cannot talk to this reader. Full stop. There is no Web
//     Bluetooth and no WebUSB in WKWebView. Any "just do it in the web view"
//     advice is wrong. The only path is native Swift → JS, which is exactly
//     what ForteCheckoutView's `cardReader` message handler exists for.
//
//     (You may see suggestions to use a "keyboard emulation" / HID reader that
//     types the card number into a focused text field. Do not. That means an
//     UNENCRYPTED reader spraying plaintext PAN into your app, which drags the
//     whole app into PCI-DSS scope — the precise thing a WebView integration is
//     supposed to avoid. The DynaFlex II Go is an encrypting reader anyway.)
//
//  2. The reader's ciphertext is DUKPT and, per Forte's own documentation,
//     "can only be decrypted by the Magensa decryption service" (MagTek's
//     service). Your server cannot decrypt it. So either Forte relays the blob
//     to Magensa on your behalf, or you hold Magensa credentials yourself.
//     ONLY FORTE CAN TELL YOU WHICH APPLIES TO YOUR ACCOUNT.
//
//  3. Forte's public docs describe eDynamo/DynaFlex integration through the
//     "MagTek SCRA Web API Host Service" — a *Windows* service on localhost.
//     USB is Windows-only. Their support portal says the DynaFlex II Go works
//     with "Forte Checkout, BillPay, and the REST API platform" over BLE on
//     iOS, but no iOS integration guide is publicly reachable (their devdocs
//     are a client-rendered SPA). Card-present will also almost certainly
//     require an EMV certification on your Forte location.
//
//  So: this file defines the seam, and ships a reader that honestly reports it
//  is unavailable. It does not fabricate a BLE implementation, because an
//  untested one would look like it works right up until it silently fails to
//  take money. Get answers to (2) and (3) from Forte first — the questions are
//  written out in eventExplore/README.md.
//

import Foundation

enum CardReaderResult {
    case approved(transactionID: String?)
    case failed(message: String)
}

/// Collects a card read from physical hardware and turns it into a Forte sale.
protocol CardReader {
    /// - Returns: the outcome. Implementations must never return `.approved`
    ///   unless the *server* confirmed the transaction was approved.
    func collectAndCharge(amount: Decimal, orderNumber: String?) async -> CardReaderResult
}

enum CardReaderFactory {
    static func make() -> CardReader {
        // Replace `MTSCRA` with the real module name once you add MagTek's iOS
        // SDK (it ships as an .xcframework; the universal SDK covers all
        // DynaFlex and DynaProx devices). Until then this resolves to the
        // unavailable reader and the checkout page hides its reader button.
        #if canImport(MTSCRA)
        return DynaFlexCardReader()
        #else
        return UnavailableCardReader()
        #endif
    }
}

/// What you get today. Fails loudly and specifically.
struct UnavailableCardReader: CardReader {
    func collectAndCharge(amount: Decimal, orderNumber: String?) async -> CardReaderResult {
        .failed(message: "Card reader not configured. Add MagTek's iOS SDK and confirm Forte's card-present API shape before enabling this.")
    }
}

/// Posts an encrypted read to our backend, which forwards it to Forte.
/// The PAN never exists in plaintext on the device or on our server.
struct EncryptedSwipe: Encodable {
    let encryptedTrack: String
    let ksn: String
    let encryptionMethod: String
}

enum SwipeSaleClient {
    struct Response: Decodable {
        let approved: Bool
        let transaction_id: String?
        let message: String?
        let error: String?
    }

    static func charge(amount: Decimal, orderNumber: String?, swipe: EncryptedSwipe) async -> CardReaderResult {
        var request = URLRequest(url: ForteConfig.endpoint("api/payments/swipe-sale"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "amount": "\(amount)",
            "order_number": orderNumber ?? "",
            "swipe": [
                "encryptedTrack": swipe.encryptedTrack,
                "ksn": swipe.ksn,
                "encryptionMethod": swipe.encryptionMethod,
            ],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            // A 402 (declined) still decodes; `approved` is the only signal that counts.
            return decoded.approved
                ? .approved(transactionID: decoded.transaction_id)
                : .failed(message: decoded.error ?? decoded.message ?? "Card declined.")
        } catch {
            return .failed(message: "Could not reach the payment server: \(error.localizedDescription)")
        }
    }
}

#if canImport(MTSCRA)
import MTSCRA

/// Sketch only — compiled solely when MagTek's SDK is present. The method names
/// below are illustrative; check them against MagTek's iOS reference before use.
struct DynaFlexCardReader: CardReader {
    func collectAndCharge(amount: Decimal, orderNumber: String?) async -> CardReaderResult {
        // 1. Discover + connect over BLE (MTSCRALib, deviceType .dynaFlex).
        // 2. Start an EMV transaction for `amount`; await the ARQC / MSR read.
        // 3. Pull the encrypted track blob + KSN from the callback.
        // 4. Hand off to the server, which talks to Forte (and Magensa).
        //
        // Note: BLE requires NSBluetoothAlwaysUsageDescription in Info.plist.
        // Connecting over Lightning/USB-C accessory protocols additionally
        // requires an MFi-registered protocol string in UISupportedExternalAccessoryProtocols.
        .failed(message: "DynaFlexCardReader is not implemented. See the header comment in CardReaderBridge.swift.")
    }
}
#endif
