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
    /// The calling app's identifier (iOS bundle ID), requested by the backend
    /// team so they can tell which client app made the call.
    var applicationIdentifier: String
    var devicePaymentConfigurationId: String?
    var organizationId: String
    var memberId: String?

    var amount: Double
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

    // --- Dynamic, from the MagTek reader read ---
    var ksn: String
    var deviceSerialNumber: String
    var emvSredData: String
    var cardType: String

    var firstName: String
    var lastName: String
    var email: String?
    var phoneNumber: String?

    var remarks: String
}

extension DynaFlexPaymentRequest {
    /// Static payload values (from the API sample). Change these to your real
    /// organization / campaign references. The four reader fields and `amount`
    /// are filled dynamically in `make(amount:card:)`.
    enum Defaults {
        static let appDeviceId = "59e6cc40-7cc8-4cf9-9c6e-93be6be05551"
        // Fallback only if Bundle.main.bundleIdentifier is somehow unavailable.
        static let applicationIdentifierFallback = "com.cl.mrfor.MrFor"
        static let organizationId = "5eaab13e-c11b-4f97-b7fc-06e265fc5f89"
        static let referenceId = "b155f057-2ab8-493f-a1d7-f4ec8ac273cb"
        static let donationId = "b155f057-2ab8-493f-a1d7-f4ec8ac273cb"
        static let campaignId = "3f1bc79b-b670-46a7-b2be-84a21772c3f7"
        static let sourceApp = "Kiosk"
        static let paymentPurpose = "Donation"
        static let deviceId = "KIOSK-001"
        static let readerType = "MagTekDynaFlexIIGo"
        static let readerSerialNumber = "DYNAFLEX-001"
        static let firstName = "Guest"
        static let lastName = "Donor"
        static let remarks = "Kiosk DynaFlex donation test payment"
        // Fallbacks used only if the reader doesn't supply a value.
        static let deviceSerialNumber = "MTDYNAFLEX001"
        static let cardType = "VISA"
    }

    /// Build the request: static defaults + the reader's dynamic fields + amount.
    static func make(amount: Decimal, card: EncryptedCardData) -> DynaFlexPaymentRequest {
        func value(_ v: String, else fallback: String) -> String { v.isEmpty ? fallback : v }
        return DynaFlexPaymentRequest(
            appDeviceId: Defaults.appDeviceId,
            applicationIdentifier: Bundle.main.bundleIdentifier ?? Defaults.applicationIdentifierFallback,
            devicePaymentConfigurationId: nil,
            organizationId: Defaults.organizationId,
            memberId: nil,
            amount: NSDecimalNumber(decimal: amount).doubleValue,
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
            // Dynamic — from the reader:
            ksn: card.ksn,
            deviceSerialNumber: value(card.deviceSerialNumber, else: Defaults.deviceSerialNumber),
            emvSredData: card.encryptedTrack,
            cardType: value(card.cardType, else: Defaults.cardType),
            firstName: Defaults.firstName,
            lastName: Defaults.lastName,
            email: nil,
            phoneNumber: nil,
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
        MTLog("➡️ POST \(urlRequest.url?.absoluteString ?? "-") (DynaFlex payment)")
        AppLogger.shared.apiRequest(
            api: "dynaflex/payment",
            method: "POST",
            url: urlRequest.url?.absoluteString ?? "-",
            body: redacted(request)
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let decoded = try? JSONDecoder().decode(DynaFlexPaymentResponse.self, from: data) {
                MTLog("🏦 DynaFlex API (HTTP \(status)) success=\(decoded.success) msg=\(decoded.message ?? "-")")
                AppLogger.shared.apiResponse(
                    api: "dynaflex/payment",
                    statusCode: status,
                    body: ["success": decoded.success, "message": decoded.message ?? ""]
                )
                return .success(decoded)
            }
            let raw = String(data: data, encoding: .utf8) ?? ""
            MTLog("❌ DynaFlex API decode failed (HTTP \(status)): \(raw.prefix(200))")
            AppLogger.shared.apiResponse(api: "dynaflex/payment", statusCode: status, error: String(raw.prefix(300)))
            return .failure(.badResponse(status: status, body: raw))
        } catch {
            MTLog("❌ DynaFlex API network error: \(error.localizedDescription)")
            AppLogger.shared.apiResponse(api: "dynaflex/payment", statusCode: nil, error: error.localizedDescription)
            return .failure(.network(error.localizedDescription))
        }
    }

    /// Mirrors the request as a dictionary for logging, with the PCI-sensitive
    /// fields (KSN, EMV SRED block) masked/previewed instead of stored in full.
    private static func redacted(_ request: DynaFlexPaymentRequest) -> [String: Any] {
        [
            "applicationIdentifier": request.applicationIdentifier,
            "organizationId": request.organizationId,
            "amount": request.amount,
            "currencyCode": request.currencyCode,
            "sourceApp": request.sourceApp,
            "paymentPurpose": request.paymentPurpose,
            "referenceId": request.referenceId,
            "deviceId": request.deviceId,
            "readerType": request.readerType,
            "readerSerialNumber": request.readerSerialNumber,
            "deviceSerialNumber": request.deviceSerialNumber,
            "cardType": request.cardType,
            "ksnPreview": LogRedaction.hexPreview(request.ksn),
            "emvSredDataPreview": LogRedaction.hexPreview(request.emvSredData),
        ]
    }
}
