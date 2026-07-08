//
//  ForteConfig.swift
//  MrFor
//
//  Points the app at the eventExplore backend. There are deliberately no Forte
//  credentials in this file, and none should ever be added: the API Secure Key
//  can move money, and anything shipped in an .ipa is readable by anyone who
//  downloads it. The app only ever talks to our own server.
//

import Foundation

enum ForteConfig {
    /// Where `eventExplore` is running.
    ///
    /// - Simulator: `localhost` works as-is.
    /// - Physical device: replace with your Mac's LAN address, e.g. `http://192.168.1.42:3000`,
    ///   and make sure the phone is on the same Wi-Fi.
    ///
    /// Plain HTTP to a local address is blocked by App Transport Security unless
    /// you opt in. Because this target uses a *generated* Info.plist, add the
    /// exception in Build Settings → "Info.plist Values" is not enough — ATS keys
    /// require a real file. Either:
    ///   1. Set `GENERATE_INFOPLIST_FILE = NO`, add an Info.plist, and set
    ///      `NSAppTransportSecurity` → `NSAllowsLocalNetworking` = YES; or
    ///   2. Run the backend behind HTTPS (ngrok, Caddy) and skip ATS entirely.
    /// Option 2 is less work and matches production more closely.
    static let backendBaseURL = URL(string: "http://localhost:3000")!

    /// Paths the WebView watches for to know the flow ended.
    /// Keep in sync with CHECKOUT_RETURN_SUCCESS / CHECKOUT_RETURN_CANCEL in `.env`.
    static let successPath = "/checkout/complete"
    static let cancelPath = "/checkout/cancel"

    /// Name of the `WKScriptMessageHandler` the checkout page looks for at
    /// `window.webkit.messageHandlers.cardReader`. The page hides its
    /// "Tap or insert card" button when this handler is absent.
    static let cardReaderHandlerName = "cardReader"

    static func checkoutURL(amount: Decimal, orderNumber: String?) -> URL {
        var components = URLComponents(
            url: backendBaseURL.appendingPathComponent("checkout.html"),
            resolvingAgainstBaseURL: false
        )!
        var items = [URLQueryItem(name: "amount", value: "\(amount)")]
        if let orderNumber, !orderNumber.isEmpty {
            items.append(URLQueryItem(name: "order_number", value: orderNumber))
        }
        components.queryItems = items
        return components.url!
    }

    static func endpoint(_ path: String) -> URL {
        backendBaseURL.appendingPathComponent(path)
    }
}

/// How a checkout attempt ended. `.cancelled` and `.failed` are distinct because
/// only one of them should be surfaced to the user as a problem.
enum CheckoutOutcome: Equatable {
    case approved(transactionID: String?)
    case cancelled
    case failed(message: String)
}
