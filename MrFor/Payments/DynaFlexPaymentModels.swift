//
//  DynaFlexPaymentModels.swift
//  MrFor
//
//  Request/response models for the MMS Kiosk DynaFlex payment API, plus a small
//  service that performs the call. The request is built from the reader's read
//  (ksn, emvSredData, deviceSerialNumber, cardType) with the rest kept as static
//  defaults; only those four fields + the amount are dynamic.
//

import Foundation

// MARK: - Request

struct DynaFlexPaymentRequest: Encodable {
    var appDeviceId: String
    var devicePaymentConfigurationId: String?
    var organizationId: String
    var memberId: String?

    var amount: Double
    var serviceFeeAmount: Double?
    var currencyCode: String

    var sourceApp: String
    var paymentPurpose: String

    var referenceId: String
    var donationId: String?
    var campaignId: String?

    var eventId: String?
    var eventRegistrationId: String?
    var eventTicketOrderId: String?

    var quantity: Int?
    var extraTicketQuantity: Int?
    var unitPrice: Double?

    var deviceId: String
    var readerType: String
    var readerSerialNumber: String

    var billingAddress: BillingAddress

    // Reader read data, nested (new backend shape).
    var cardEmvData: CardEmvData

    var remarks: String

    struct BillingAddress: Encodable {
        var firstName: String
        var lastName: String
        var phone: String?
        var physicalAddress: PhysicalAddress?
    }
    struct PhysicalAddress: Encodable {
        var streetLine1: String?
        var streetLine2: String?
        var locality: String?
        var region: String?
        var postalCode: String?
    }
    struct CardEmvData: Encodable {
        var transactionOutput: TransactionOutput
    }
    struct TransactionOutput: Encodable {
        var ksn: String
        var deviceSerialNumber: String
        var emvSredData: String
        var cardType: String   // Forte DFDF52 numeric code, e.g. "05"/"06"
    }
}

extension DynaFlexPaymentRequest {
    /// Static payload values. Change these to your real organization / campaign
    /// references. The reader fields + amount are filled in `make(amount:card:)`.
    enum Defaults {
        static let appDeviceId = "59e6cc40-7cc8-4cf9-9c6e-93be6be05551"
        static let organizationId = "5eaab13e-c11b-4f97-b7fc-06e265fc5f89"
        static let referenceId = "b155f057-2ab8-493f-a1d7-f4ec8ac273cb"
        static let donationId = "b155f057-2ab8-493f-a1d7-f4ec8ac273cb"
        static let campaignId = "3f1bc79b-b670-46a7-b2be-84a21772c3f7"
        static let sourceApp = "Kiosk"
        static let paymentPurpose = "Donation"
        static let deviceId = "KIOSK-001"
        static let readerType = "MagTekDynaFlexIIGo"
        static let readerSerialNumber = "DYNAFLEX-001"
        static let remarks = "Kiosk DynaFlex donation test payment"
        // Fallbacks used only if the reader doesn't supply a value.
        static let deviceSerialNumber = "MTDYNAFLEX001"
        static let cardTypeCode = "05"
    }

    /// Build the request: static defaults + the reader's dynamic fields + amount.
    static func make(amount: Decimal, card: EncryptedCardData) -> DynaFlexPaymentRequest {
        func value(_ v: String, else fallback: String) -> String { v.isEmpty ? fallback : v }
        return DynaFlexPaymentRequest(
            appDeviceId: Defaults.appDeviceId,
            devicePaymentConfigurationId: nil,
            organizationId: Defaults.organizationId,
            memberId: nil,
            amount: NSDecimalNumber(decimal: amount).doubleValue,
            serviceFeeAmount: nil,
            currencyCode: "USD",
            sourceApp: Defaults.sourceApp,
            paymentPurpose: Defaults.paymentPurpose,
            referenceId: Defaults.referenceId,
            donationId: Defaults.donationId,
            campaignId: Defaults.campaignId,
            eventId: nil,
            eventRegistrationId: nil,
            eventTicketOrderId: nil,
            quantity: nil,
            extraTicketQuantity: nil,
            unitPrice: nil,
            deviceId: Defaults.deviceId,
            readerType: Defaults.readerType,
            readerSerialNumber: Defaults.readerSerialNumber,
            billingAddress: BillingAddress(
                firstName: "Jennifer",
                lastName: "McFly",
                phone: "444-444-4444",
                physicalAddress: PhysicalAddress(
                    streetLine1: "8003 Clock Tower Ln",
                    streetLine2: "Suite 200",
                    locality: "Hill Valley",
                    region: "CA",
                    postalCode: "46203"
                )
            ),
            cardEmvData: CardEmvData(transactionOutput: TransactionOutput(
                // Dynamic — from the reader read:
                ksn: card.ksn,
                deviceSerialNumber: value(card.deviceSerialNumber, else: Defaults.deviceSerialNumber),
                emvSredData: card.sredData.isEmpty ? card.encryptedTrack : card.sredData,
                cardType: value(card.cardTypeCode, else: Defaults.cardTypeCode)
            )),
            remarks: Defaults.remarks
        )
    }
}

// MARK: - Response

struct DynaFlexPaymentResponse: Decodable {
    let success: Bool
    let message: String?
    let data: PaymentData?

    struct PaymentData: Decodable {
        let paymentId: String?
        let gatewayTransactionId: String?
        let authorizationCode: String?
        let status: String?
        let responseCode: String?
        let responseDescription: String?
        let receiptNo: String?
        let amount: Double?
        let paymentDate: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            paymentId = c.string("paymentId", "PaymentId")
            gatewayTransactionId = c.string("gatewayTransactionId", "GatewayTransactionId")
            authorizationCode = c.string("authorizationCode", "AuthorizationCode")
            status = c.string("status", "Status")
            responseCode = c.string("responseCode", "ResponseCode")
            responseDescription = c.string("responseDescription", "ResponseDescription")
            receiptNo = c.string("receiptNo", "ReceiptNo")
            amount = c.double("amount", "Amount")
            paymentDate = c.string("paymentDate", "PaymentDate")
        }
    }

    // The API returns camelCase on success but PascalCase on error responses;
    // decode tolerantly so we always surface the server's message.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        success = c.bool("success", "Success") ?? false
        message = c.string("message", "Message")
        data = c.decodeIfPresent(PaymentData.self, "data", "Data")
    }
}

/// A CodingKey that accepts any string, for case-tolerant decoding.
private struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

private extension KeyedDecodingContainer where Key == AnyKey {
    func bool(_ names: String...) -> Bool? {
        for n in names { if let v = try? decode(Bool.self, forKey: AnyKey(n)) { return v } }
        return nil
    }
    func string(_ names: String...) -> String? {
        for n in names { if let v = try? decode(String.self, forKey: AnyKey(n)) { return v } }
        return nil
    }
    func double(_ names: String...) -> Double? {
        for n in names { if let v = try? decode(Double.self, forKey: AnyKey(n)) { return v } }
        return nil
    }
    func decodeIfPresent<T: Decodable>(_ type: T.Type, _ names: String...) -> T? {
        for n in names { if let v = try? decode(T.self, forKey: AnyKey(n)) { return v } }
        return nil
    }
}

// MARK: - Service

enum PaymentServiceError: Error {
    case encoding
    case badResponse(status: Int, body: String)
    case network(String)

    var message: String {
        switch self {
        case .encoding:
            return "Could not prepare the payment request."
        case .badResponse(let status, let body):
            // Include the server's raw body so failures are debuggable in-app.
            let snippet = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return snippet.isEmpty
                ? "Unexpected server response (HTTP \(status))."
                : "Server error (HTTP \(status)): \(snippet.prefix(300))"
        case .network(let m):
            return "Couldn’t reach the payment server. \(m)"
        }
    }
}

enum DynaFlexPaymentService {
    static func process(_ request: DynaFlexPaymentRequest) async -> Result<DynaFlexPaymentResponse, PaymentServiceError> {
        guard let body = try? JSONEncoder().encode(request) else {
            AppLogger.shared.guardFailure("Failed to encode DynaFlex payment request")
            return .failure(.encoding)
        }
        let urlRequest = APIEndpoint.dynaFlexPayment.makeRequest(body: body)
        let url = urlRequest.url?.absoluteString ?? "-"

        // Print the EXACT request body being POSTed (full, unredacted) so the
        // console shows precisely what the API receives — the whole point of
        // debugging DECRYPT TIMEOUT is seeing the real emvSredData/ksn sent.
        let requestJSON = String(data: body, encoding: .utf8) ?? "<non-utf8 body>"
        print("\n================ DYNAFLEX API REQUEST ================\nPOST \(url)\n\(requestJSON)\n=====================================================\n")
        MTLog("➡️ POST \(url) (DynaFlex payment)")
        AppLogger.shared.apiRequest(api: "dynaflex/payment", method: "POST", url: url, body: request.fullLoggableDict)

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"

            // Print the EXACT raw response body, in full.
            print("\n================ DYNAFLEX API RESPONSE ===============\nHTTP \(status)\n\(raw)\n=====================================================\n")

            if let decoded = try? JSONDecoder().decode(DynaFlexPaymentResponse.self, from: data) {
                MTLog("🏦 DynaFlex API (HTTP \(status)) success=\(decoded.success) msg=\(decoded.message ?? "-")")
                AppLogger.shared.apiResponse(
                    api: "dynaflex/payment", statusCode: status,
                    body: ["success": decoded.success, "message": decoded.message ?? "", "raw": raw]
                )
                return .success(decoded)
            }
            MTLog("❌ DynaFlex API decode failed (HTTP \(status)): \(raw.prefix(200))")
            AppLogger.shared.apiResponse(api: "dynaflex/payment", statusCode: status, body: ["raw": raw], error: "decode failed")
            return .failure(.badResponse(status: status, body: raw))
        } catch {
            print("\n================ DYNAFLEX API ERROR =================\n\(error.localizedDescription)\n=====================================================\n")
            MTLog("❌ DynaFlex API network error: \(error.localizedDescription)")
            AppLogger.shared.apiResponse(api: "dynaflex/payment", statusCode: nil, error: error.localizedDescription)
            return .failure(.network(error.localizedDescription))
        }
    }

}

extension DynaFlexPaymentRequest {
    /// The complete request as a dictionary — every field, full values (including
    /// the full ksn + emvSredData ciphertext). Used for logging so the console
    /// shows exactly what's sent. Safe: this is DUKPT ciphertext, never a PAN.
    var fullLoggableDict: [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }
}
