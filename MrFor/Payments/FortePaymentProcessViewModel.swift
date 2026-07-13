//
//  FortePaymentProcessViewModel.swift
//  MrFor
//
//  Owns all payment orchestration for the payment screen so the View stays thin:
//
//   • Reader (DynaFlex II Go) → reads the card → POSTs to the MMS Kiosk DynaFlex
//     API (APIEndpoint.dynaFlexPayment) → shows a success/failure popup.
//   • Manual entry (WKWebView → eventExplore keyed sale) and the sandbox test
//     charge → shows the receipt. This logic is unchanged; it just lives here now.
//

import Foundation

@MainActor
@Observable
final class FortePaymentProcessViewModel {

    /// Busy state for any in-flight payment.
    private(set) var isProcessing = false
    /// Transient status line (e.g. "Processing payment…"). Reader prompts like
    /// "PRESENT CARD" come from the engine's own `statusMessage`.
    private(set) var processingMessage: String?

    /// Success/failure popup (DynaFlex reader flow).
    var alert: PaymentAlert?

    /// Receipt presentation (manual entry & test charge — eventExplore flow).
    var receiptTransactionID: String?
    private(set) var chargedAmount: Decimal = 0

    // MARK: - Reader → DynaFlex payment API → popup

    /// Read the card from the connected reader and process it through the MMS
    /// Kiosk DynaFlex API. Shows a popup with the API's message either way.
    func processReaderPayment(using reader: ReaderEngine, amount: Decimal) async {
        isProcessing = true
        processingMessage = "Waiting for card…"
        defer { isProcessing = false; processingMessage = nil }

        AppLogger.shared.beginPayment()
        MTLog("🛒 DynaFlex payment: reading card for \(amount)")
        AppLogger.shared.reader("Card read requested", data: ["amount": "\(amount)"])
        let read = await reader.readCard(amount: amount)

        switch read {
        case .failed(let message):
            AppLogger.shared.error("Card read failed", data: ["message": message])
            alert = .failure("Payment Failed", message)
            AppLogger.shared.endPayment(result: "reader_failed")

        case .success(let card):
            AppLogger.shared.reader("Card read OK", data: card.loggableDict)
            processingMessage = "Processing payment…"
            let request = DynaFlexPaymentRequest.make(amount: amount, card: card)
            let result = await DynaFlexPaymentService.process(request)

            switch result {
            case .success(let response):
                if response.success {
                    alert = .success(
                        "Payment Successful",
                        response.message ?? "Your payment was completed successfully."
                    )
                    AppLogger.shared.endPayment(result: "success")
                } else {
                    alert = .failure(
                        "Payment Failed",
                        response.message ?? "The payment could not be completed."
                    )
                    AppLogger.shared.endPayment(result: "declined")
                }
            case .failure(let error):
                alert = .failure("Payment Failed", error.message)
                AppLogger.shared.endPayment(result: "api_error")
            }
        }
    }


    // MARK: - Manual entry & test charge → receipt (existing logic)

    /// Result handler for the manual card WebView. Unchanged behavior: approval
    /// presents the receipt; decline/failure shows a popup.
    func handleManualEntry(_ outcome: PaymentOutcome, amount: Decimal) {
        switch outcome {
        case .approved(let txn, _):
            if let txn { chargedAmount = amount; receiptTransactionID = txn }
            AppLogger.shared.info("Manual entry approved", data: ["hasTxn": txn != nil])
        case .declined(let message):
            alert = .failure("Declined", message)
            AppLogger.shared.warning("Manual entry declined", data: ["message": message])
        case .failed(let message):
            alert = .failure("Payment Failed", message)
            AppLogger.shared.error("Manual entry failed", data: ["message": message])
        }
    }

    /// Sandbox-only keyed test charge via eventExplore → receipt on approval.
    func testCharge(amount: Decimal, orderNumber: String?) async {
        isProcessing = true
        processingMessage = "Processing…"
        defer { isProcessing = false; processingMessage = nil }

        AppLogger.shared.beginPayment()
        MTLog("🧪 Test charge (sandbox card): \(amount)")
        let outcome = await PaymentAPIClient.testSale(amount: amount, orderNumber: orderNumber, card: .sandboxVisa)
        handleManualEntry(outcome, amount: amount)
        switch outcome {
        case .approved: AppLogger.shared.endPayment(result: "success")
        case .declined: AppLogger.shared.endPayment(result: "declined")
        case .failed: AppLogger.shared.endPayment(result: "api_error")
        }
    }
}
