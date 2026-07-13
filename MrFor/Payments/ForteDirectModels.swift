//
//  ForteDirectModels.swift
//  MrFor
//
//  Direct-to-Forte REST v3 transaction (bypasses the MMS backend). Added
//  alongside DynaFlexPaymentModels — the MMS models/service are untouched and
//  can be switched back to at any time. This path posts the reader read straight
//  to Forte's `transactions` endpoint, which is what proved the decryptor works
//  (it returned a real decline, "KSN REPLAY", instead of the backend's timeout).
//
//  ⚠️ SECURITY — TESTING ONLY:
//  This calls Forte directly, so the app holds the Forte API credentials. That's
//  fine for sandbox debugging, but Forte secrets must NEVER ship in a production
//  app (an .ipa is extractable). For production, go back to the MMS-backend path
//  (which keeps the secret server-side). Rotate this sandbox key when done.
//

import Foundation

enum ForteDirectConfig {
    static let baseURL = "https://sandbox.forte.net/api/v3"
    static let organizationId = "org_528047"
    static let locationId = "loc_432276"

    // Sandbox credentials — testing only (see security note above).
    private static let apiAccessId = "3a63cc942adba7a55270038ec92badf0"
    private static let apiSecureKey = "0275cac62fdfea1adc956a55f32e5cfd"

    static var transactionsURL: URL? {
        URL(string: "\(baseURL)/organizations/\(organizationId)/locations/\(locationId)/transactions")
    }

    static var authorizationHeader: String {
        "Basic " + Data("\(apiAccessId):\(apiSecureKey)".utf8).base64EncodedString()
    }
}

// MARK: - Request (Forte REST v3 shape)

struct ForteTransactionRequest: Encodable {
    let action: String
    let authorization_amount: String
    let billing_address: ForteBillingAddress
    let card: ForteCard

    struct ForteBillingAddress: Encodable {
        let first_name: String
        let last_name: String
        let phone: String?
        let physical_address: FortePhysicalAddress?
    }
    struct FortePhysicalAddress: Encodable {
        let street_line1: String?
        let street_line2: String?
        let locality: String?
        let region: String?
        let postal_code: String?
    }
    struct ForteCard: Encodable {
        let card_reader: String     // "dynaflex2go"
        let card_emv_data: String   // stringified {"TransactionOutput":{…}}
    }

    /// Build the Forte request from a reader read. Static billing defaults; the
    /// four dynamic fields (KSN / DeviceSerialNumber / EMVSREDData / CardType)
    /// come from the dip and are packed into `card_emv_data`.
    static func make(card: EncryptedCardData, amount: Decimal) -> ForteTransactionRequest {
        let transactionOutput: [String: Any] = [
            "TransactionOutput": [
                "KSN": card.ksn,
                "DeviceSerialNumber": card.deviceSerialNumber,
                "EMVSREDData": card.sredData.isEmpty ? card.encryptedTrack : card.sredData,
                "CardType": card.cardTypeCode.isEmpty ? "05" : card.cardTypeCode,
            ],
        ]
        let emvString = (try? JSONSerialization.data(withJSONObject: transactionOutput))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        return ForteTransactionRequest(
            action: "sale",
            authorization_amount: NSDecimalNumber(decimal: amount).stringValue,
            billing_address: ForteBillingAddress(
                first_name: "Guest",
                last_name: "Donor",
                phone: "444-444-4444",
                physical_address: FortePhysicalAddress(
                    street_line1: "8003 Clock Tower Ln",
                    street_line2: "Suite 200",
                    locality: "Hill Valley",
                    region: "CA",
                    postal_code: "46203"
                )
            ),
            card: ForteCard(card_reader: "dynaflex2go", card_emv_data: emvString)
        )
    }
}

// MARK: - Response (Forte REST v3 shape)

struct ForteTransactionResponse: Decodable {
    let transaction_id: String?
    let location_id: String?
    let authorization_amount: Double?
    let authorization_code: String?
    let card: ForteResponseCard?
    let response: ForteResponse?

    struct ForteResponse: Decodable {
        let environment: String?
        let response_type: String?   // A = Approved, D = Declined, E = Error
        let response_code: String?   // A01, U93, …
        let response_desc: String?
        let authorization_code: String?
        let avs_result: String?
        let cvv_result: String?
    }
    struct ForteResponseCard: Decodable {
        let name_on_card: String?
        let last_4_account_number: String?
        let masked_account_number: String?
        let card_type: String?
        let card_reader: String?
    }

    /// Forte returns approval as response_code "A01" (response_type "A").
    var isApproved: Bool { response?.response_code == "A01" }

    /// Human-readable line for the popup (desc + code, plus auth on approval).
    var displayMessage: String {
        var parts: [String] = []
        if let desc = response?.response_desc, !desc.isEmpty { parts.append(desc) }
        if let code = response?.response_code, !code.isEmpty { parts.append("(\(code))") }
        let auth = authorization_code ?? response?.authorization_code
        if isApproved, let auth, !auth.isEmpty { parts.append("· Auth \(auth)") }
        return parts.isEmpty ? "No response detail." : parts.joined(separator: " ")
    }
}

// MARK: - Service

enum ForteTransactionService {
    static func process(card: EncryptedCardData, amount: Decimal) async -> Result<ForteTransactionResponse, PaymentServiceError> {
        guard let url = ForteDirectConfig.transactionsURL else { return .failure(.encoding) }
        let request = ForteTransactionRequest.make(card: card, amount: amount)
        guard let body = try? JSONEncoder().encode(request) else {
            AppLogger.shared.guardFailure("Failed to encode Forte transaction request")
            return .failure(.encoding)
        }

        var urlRequest = URLRequest(url: url, timeoutInterval: 60)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(ForteDirectConfig.authorizationHeader, forHTTPHeaderField: "Authorization")
        urlRequest.setValue(ForteDirectConfig.organizationId, forHTTPHeaderField: "X-Forte-Auth-Organization-Id")
        urlRequest.httpBody = body

        let requestJSON = String(data: body, encoding: .utf8) ?? "<non-utf8>"
        print("\n================ FORTE DIRECT REQUEST ================\nPOST \(url.absoluteString)\n\(requestJSON)\n=====================================================\n")
        AppLogger.shared.apiRequest(api: "forte/transactions", method: "POST", url: url.absoluteString,
                                    body: (try? JSONSerialization.jsonObject(with: body)) as? [String: Any])

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("\n================ FORTE DIRECT RESPONSE ===============\nHTTP \(status)\n\(raw)\n=====================================================\n")

            if let decoded = try? JSONDecoder().decode(ForteTransactionResponse.self, from: data) {
                MTLog("🏦 Forte (HTTP \(status)) approved=\(decoded.isApproved) — \(decoded.displayMessage)")
                AppLogger.shared.apiResponse(api: "forte/transactions", statusCode: status,
                                             body: ["approved": decoded.isApproved,
                                                    "response_code": decoded.response?.response_code ?? "",
                                                    "response_desc": decoded.response?.response_desc ?? "",
                                                    "raw": raw])
                return .success(decoded)
            }
            AppLogger.shared.apiResponse(api: "forte/transactions", statusCode: status, body: ["raw": raw], error: "decode failed")
            return .failure(.badResponse(status: status, body: raw))
        } catch {
            print("\n================ FORTE DIRECT ERROR =================\n\(error.localizedDescription)\n=====================================================\n")
            AppLogger.shared.apiResponse(api: "forte/transactions", statusCode: nil, error: error.localizedDescription)
            return .failure(.network(error.localizedDescription))
        }
    }
}
