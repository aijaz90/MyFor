//
//  ManualCardView.swift
//  MrFor
//
//  "Enter card manually" — loads the backend's card-entry page (Forte-style form
//  with validation) in a WKWebView. The page collects the card, posts it to
//  /api/payments/manual-sale (add card + charge in one step), and hands the
//  result back to the app through a JS → native message bridge. The app then
//  shows the same receipt as a reader sale.
//

import SwiftUI
@preconcurrency import WebKit

struct ManualCardView: View {
    let amount: Decimal
    let orderNumber: String?
    let onFinish: (PaymentOutcome) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var loading = true

    /// Built safely — no force unwraps. Returns nil only if the base URL is somehow invalid.
    private var url: URL? {
        guard var comps = URLComponents(url: ForteConfig.endpoint("card-entry.html"),
                                        resolvingAgainstBaseURL: false) else { return nil }
        comps.queryItems = [
            URLQueryItem(name: "amount", value: NSDecimalNumber(decimal: amount).stringValue),
            URLQueryItem(name: "order_number", value: orderNumber ?? ""),
        ]
        return comps.url
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if let url {
                    CardEntryWebView(url: url, isLoading: $loading) { outcome in
                        onFinish(outcome)
                        dismiss()
                    }
                    .ignoresSafeArea(edges: .bottom)

                    if loading { ProgressView().controlSize(.large) }
                } else {
                    ContentUnavailableView(
                        "Invalid server URL",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Couldn’t build the card page URL from the current server setting.")
                    )
                }
            }
            .navigationTitle("Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - WKWebView

private struct CardEntryWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    let onResult: (PaymentOutcome) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(WeakBridge(context.coordinator), name: "manualCard")

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.websiteDataStore = .nonPersistent()   // card data must not persist

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "manualCard")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: CardEntryWebView
        init(_ parent: CardEntryWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            MTLog("❌ Card page failed to load: \(error.localizedDescription)")
            parent.onResult(.failed(message: "Couldn’t open the card form. Is the server reachable? (\(error.localizedDescription))"))
        }

        // JS bridge: the page posts the sale result here.
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "manualCard", let body = message.body as? [String: Any] else { return }
            let approved = body["approved"] as? Bool ?? false
            if approved {
                let txn = (body["transaction_id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                let auth = (body["authorization_code"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                MTLog("💳 Manual card approved: txn=\(txn ?? "-")")
                parent.onResult(.approved(transactionID: txn, authCode: auth))
            } else {
                let msg = body["error"] as? String ?? "Card declined."
                MTLog("🚫 Manual card declined: \(msg)")
                parent.onResult(.declined(message: msg))
            }
        }
    }
}

/// Breaks the WKUserContentController → handler → WebView retain cycle.
private final class WeakBridge: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
