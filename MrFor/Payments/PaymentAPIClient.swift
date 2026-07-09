//
//  PaymentAPIClient.swift
//  MrFor
//
//  Talks to the eventExplore backend, which holds the Forte credentials and
//  makes the actual REST API v3 calls. The app never sees a secret key.
//

import Foundation

struct SaleResponse: Decodable {
    let approved: Bool
    let transaction_id: String?
    let authorization_code: String?
    let message: String?
    let error: String?
}

/// Receipt for a completed transaction, from GET /api/payments/receipt/:id.
struct Receipt: Decodable {
    let transaction_id: String?
    let approved: Bool
    let status: String?
    let amount: Double?
    let currency: String?
    let authorization_code: String?
    let response_code: String?
    let message: String?
    let date: String?
    let card: ReceiptCard?
    let avs_result: String?
    let cvv_result: String?
    let merchant_name: String?

    struct ReceiptCard: Decodable {
        let type: String?
        let last4: String?
        let masked: String?
        let name_on_card: String?
    }
}

enum PaymentAPIClient {
    /// Card-present sale from an encrypted DynaFlex read. THE PRIMARY path.
    static func cardPresentSale(amount: Decimal, orderNumber: String?, swipe: EncryptedCardData) async -> PaymentOutcome {
        let body: [String: Any] = [
            "amount": "\(amount)",
            "order_number": orderNumber ?? "",
            "swipe": [
                "encryptedTrack": swipe.encryptedTrack,
                "ksn": swipe.ksn,
                "encryptionMethod": swipe.encryptionMethod,
                "entryMode": swipe.entryMode.rawValue,
            ],
        ]
        return await post("api/payments/card-present-sale", body)
    }

    /// Keyed test sale. Sandbox only; lets you exercise the full charge + result
    /// flow before the encrypted reader path is certified.
    static func testSale(amount: Decimal, orderNumber: String?, card: TestCard) async -> PaymentOutcome {
        let body: [String: Any] = [
            "amount": "\(amount)",
            "order_number": orderNumber ?? "",
            "card": [
                "nameOnCard": card.name,
                "accountNumber": card.number,
                "expireMonth": card.month,
                "expireYear": card.year,
                "cvv": card.cvv,
            ],
        ]
        return await post("api/payments/test-sale", body)
    }

    /// Fetch the receipt for a completed transaction (GET). Returns nil on failure.
    static func receipt(transactionID: String) async -> Receipt? {
        let url = ForteConfig.endpoint("api/payments/receipt/\(transactionID)")
        logRequest(api: "receipt", method: "GET", url: url, body: nil)
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            logResponse(api: "receipt", statusCode: code, data: data)
            let receipt = try JSONDecoder().decode(Receipt.self, from: data)
            return receipt
        } catch {
            MTLog("❌ Receipt fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Transport

    private static func post(_ path: String, _ body: [String: Any]) async -> PaymentOutcome {
        let url = ForteConfig.endpoint(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let apiName = path.components(separatedBy: "/").last ?? path
        logRequest(api: apiName, method: "POST", url: url, body: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            logResponse(api: apiName, statusCode: code, data: data)
            let r = try JSONDecoder().decode(SaleResponse.self, from: data)
            // `approved` is the only signal that money moved. A 402 body decodes fine.
            if r.approved {
                return .approved(transactionID: r.transaction_id, authCode: r.authorization_code)
            }
            let msg = r.error ?? r.message ?? "Card declined."
            return .declined(message: msg)
        } catch {
            MTLog("❌ Network error to \(url.absoluteString): \(error.localizedDescription)")
            return .failed(message: "Could not reach the payment server. Is eventExplore running and reachable? (\(error.localizedDescription))")
        }
    }

    // MARK: - Copy-paste-ready logging

    /// Prints the request as pretty JSON, labeled with the API name, so it can
    /// be pasted straight into Postman/Swagger while debugging. DEBUG-only —
    /// never fires in a release build.
    private static func logRequest(api: String, method: String, url: URL, body: [String: Any]?) {
        #if DEBUG
        var text = "\n🔵 API REQUEST — \(api)\n\(method) \(url.absoluteString)"
        if let body, let json = prettyJSONString(body) {
            text += "\n\(json)"
        }
        print(text)
        #endif
    }

    /// Prints the response as pretty JSON, labeled with the same API name, so
    /// request/response pairs are easy to find and copy from the console.
    private static func logResponse(api: String, statusCode: Int?, data: Data?) {
        #if DEBUG
        var text = "\n🟢 API RESPONSE — \(api)"
        if let statusCode { text += " (HTTP \(statusCode))" }
        if let data, let object = try? JSONSerialization.jsonObject(with: data), let json = prettyJSONString(object) {
            text += "\n\(json)"
        } else if let data, let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
            text += "\n\(raw)"
        } else {
            text += "\n<no body>"
        }
        print(text)
        #endif
    }

    private static func prettyJSONString(_ object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }
}

struct TestCard {
    var name: String
    var number: String
    var month: Int
    var year: Int
    var cvv: String

    /// Forte sandbox test Visa.
    static let sandboxVisa = TestCard(name: "Test Buyer", number: "4111111111111111", month: 12, year: 2029, cvv: "123")
}
