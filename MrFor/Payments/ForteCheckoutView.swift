//
//  ForteCheckoutView.swift
//  MrFor
//
//  Hosts the eventExplore checkout page in a WKWebView and watches navigation
//  for the terminal URLs so the user is never stranded on a web page after
//  paying. Forte has no native iOS SDK, so this WebView *is* the integration.
//

import SwiftUI
@preconcurrency import WebKit

struct ForteCheckoutView: View {
    let amount: Decimal
    let orderNumber: String?
    let onFinish: (CheckoutOutcome) -> Void

    @State private var isLoading = true

    var body: some View {
        ZStack {
            CheckoutWebView(
                url: ForteConfig.checkoutURL(amount: amount, orderNumber: orderNumber),
                amount: amount,
                onFinish: onFinish,
                isLoading: $isLoading
            )
            .ignoresSafeArea(edges: .bottom)

            if isLoading {
                ProgressView().controlSize(.large)
            }
        }
    }
}

// MARK: - UIViewRepresentable

private struct CheckoutWebView: UIViewRepresentable {
    let url: URL
    /// Authoritative amount, used when the page's bridge message omits or mangles it.
    let amount: Decimal
    let onFinish: (CheckoutOutcome) -> Void
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()

        // WKUserContentController retains its message handler strongly, and the
        // handler here is the Coordinator, which the WebView's configuration
        // reaches back to. Registering the Coordinator directly leaks the whole
        // graph on dismiss. Route through a weak box instead.
        controller.add(WeakMessageHandler(context.coordinator), name: ForteConfig.cardReaderHandlerName)

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        // Card data must never survive the sheet.
        config.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        context.coordinator.webView = webView

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        // Balance the `add(_:name:)` above; otherwise the handler outlives the view.
        webView.configuration.userContentController
            .removeScriptMessageHandler(forName: ForteConfig.cardReaderHandlerName)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: CheckoutWebView
        weak var webView: WKWebView?
        private let reader: CardReader = CardReaderFactory.make()

        init(_ parent: CheckoutWebView) { self.parent = parent }

        // MARK: Navigation interception

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow); return
            }

            // Only trust terminal URLs coming from our own backend. A page in the
            // WebView could otherwise navigate to `/checkout/complete` on some
            // other host and fake an approval.
            let sameOrigin = url.host == ForteConfig.backendBaseURL.host
                && url.port == ForteConfig.backendBaseURL.port

            if sameOrigin, url.path == ForteConfig.successPath {
                decisionHandler(.cancel)
                let txn = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first { $0.name == "transaction_id" }?.value
                // NOTE: this reports what the *page* claims. The page only reaches
                // here after our server confirmed `approved`. For anything you
                // ship, also confirm server-side (webhook or a GET on the
                // transaction) before handing over goods.
                parent.onFinish(.approved(transactionID: txn))
                return
            }

            if sameOrigin, url.path == ForteConfig.cancelPath {
                decisionHandler(.cancel)
                parent.onFinish(.cancelled)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.onFinish(.failed(message: error.localizedDescription))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            // Almost always: backend not running, or ATS blocking http://localhost.
            parent.onFinish(.failed(message: "Could not reach checkout. Is eventExplore running? (\(error.localizedDescription))"))
        }

        // MARK: JS → native bridge (card reader)

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == ForteConfig.cardReaderHandlerName else { return }
            let body = message.body as? [String: Any] ?? [:]
            let amount = Decimal(string: "\(body["amount"] ?? "")") ?? parent.amount
            let orderNumber = body["orderNumber"] as? String

            Task { @MainActor in
                let result = await reader.collectAndCharge(amount: amount, orderNumber: orderNumber)
                self.deliverToPage(result)
            }
        }

        /// Hand the outcome back to `window.onCardReaderResult` in the page.
        @MainActor
        private func deliverToPage(_ result: CardReaderResult) {
            let payload: [String: Any]
            switch result {
            case .approved(let txn):
                payload = ["approved": true, "transaction_id": txn ?? ""]
            case .failed(let message):
                payload = ["approved": false, "error": message]
            }

            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else { return }

            webView?.evaluateJavaScript("window.onCardReaderResult?.(\(json));")
        }
    }
}

/// Breaks the `WKUserContentController` → handler → WebView retain cycle.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
