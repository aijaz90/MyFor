//
//  AppLogger.swift
//  MrFor
//
//  Centralized, structured logging for the whole app: local console (DEBUG),
//  a local on-device file mirror (LocalLogStore), and Firebase Firestore —
//  so a payment run by a tester on the other side of the world can be
//  inspected remotely, without waiting on screenshots or emailed logs.
//
//  Firestore layout:
//
//    RealReaderLogs/{sessionId}                — one doc per app launch
//        appVersion, buildNumber, deviceName, deviceModel, iosVersion,
//        sessionStart, sessionEnd, status
//      /logs/{autoId}                          — one doc per log line
//        timestamp, level, screen, file, function, line, message, data,
//        paymentId (present while a charge attempt is in flight, so you can
//        filter "all logs for one payment" in the Firebase console)
//
//  Card data policy: this app never handles a plaintext PAN — the reader only
//  ever produces DUKPT-encrypted ciphertext (KSN/ARQC/SRED/batch/track), which
//  is what gets logged in full (see `EncryptedCardData.loggableDict`) from
//  both the real charge flow (PaymentView) and the debug "Verify · Tap to Pay"
//  flow (BluetoothDevicesView → ReaderDataView), for remote debugging. Only
//  genuinely sensitive fields (CVV, PIN, manual-entry card number) are masked
//  via `LogRedaction` before ever reaching Firestore or the local log mirror.
//
//  Crashlytics: every log line is also mirrored as a Crashlytics breadcrumb
//  (`log(_:)`), and `.error`/`.guardFailure` lines are additionally recorded
//  as non-fatal errors (`record(error:)`) — so if the app actually crashes,
//  the crash report shows the last breadcrumbs plus any recent non-fatals,
//  and the session/payment id custom keys let you cross-reference the same
//  event in Firestore.
//

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseCrashlytics

final class AppLogger {
    static let shared = AppLogger()

    /// One id per app launch. Every log line in this run is filed under it.
    private(set) var sessionId = UUID().uuidString

    /// Set while a charge attempt is in flight; attached to every log so all
    /// lines for one payment can be filtered together. See `beginPayment`.
    private(set) var currentPaymentId: String?

    /// The last screen reported via `screen(_:)`. Every log line defaults to
    /// this when it doesn't pass its own `screen` explicitly, so `screen`
    /// always shows up in Firestore/local logs — not just on screen-open events.
    private(set) var currentScreen = "Unknown"

    private let sessionCollection = "RealReaderLogs"
    private var didStart = false

    private var db: Firestore? {
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore()
    }

    private init() {}

    // MARK: - Session lifecycle

    /// Call once, right after `FirebaseApp.configure()`, when the app launches.
    func startSession() {
        guard !didStart else { return }
        didStart = true
        sessionId = UUID().uuidString

        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        Crashlytics.crashlytics().setCustomValue(sessionId, forKey: "sessionId")
        Crashlytics.crashlytics().setCustomValue(DeviceContext.appVersion, forKey: "appVersion")
        Crashlytics.crashlytics().setCustomValue(DeviceContext.deviceModel, forKey: "deviceModel")

        let payload: [String: Any] = [
            "appVersion": DeviceContext.appVersion,
            "buildNumber": DeviceContext.buildNumber,
            "deviceName": DeviceContext.deviceName,
            "deviceModel": DeviceContext.deviceModel,
            "iosVersion": DeviceContext.osVersion,
            "sessionStart": FieldValue.serverTimestamp(),
            "status": "active",
        ]
        db?.collection(sessionCollection).document(sessionId).setData(payload) { error in
            Self.logFirestoreErrorIfNeeded(error, context: "startSession")
        }
        info("App session started")
    }

    /// Call when the app moves to background/is about to terminate.
    func endSession(status: String = "ended") {
        info("App session ended (\(status))")
        db?.collection(sessionCollection).document(sessionId).setData(
            ["sessionEnd": FieldValue.serverTimestamp(), "status": status],
            merge: true
        ) { error in
            Self.logFirestoreErrorIfNeeded(error, context: "endSession")
        }
    }

    /// Starts a correlation id for one charge attempt (reader connect → card
    /// read → API request → API response). Call `endPayment` when it's done.
    @discardableResult
    func beginPayment() -> String {
        let id = String(UUID().uuidString.prefix(8))
        currentPaymentId = id
        Crashlytics.crashlytics().setCustomValue(id, forKey: "paymentId")
        info("Payment attempt started", data: ["paymentId": id])
        return id
    }

    func endPayment(result: String) {
        info("Payment attempt finished", data: ["result": result])
        currentPaymentId = nil
        Crashlytics.crashlytics().setCustomValue("", forKey: "paymentId")
    }

    // MARK: - Public logging API
    // All of these auto-capture call-site file/function/line via default
    // parameters — callers don't need to pass anything but the message/data.

    func info(_ message: String, data: [String: Any]? = nil, screen: String? = nil,
              file: String = #fileID, function: String = #function, line: Int = #line) {
        write(level: .info, message: message, data: data, screen: screen, file: file, function: function, line: line)
    }

    func warning(_ message: String, data: [String: Any]? = nil, screen: String? = nil,
                 file: String = #fileID, function: String = #function, line: Int = #line) {
        write(level: .warning, message: message, data: data, screen: screen, file: file, function: function, line: line)
    }

    func error(_ message: String, data: [String: Any]? = nil, screen: String? = nil,
               file: String = #fileID, function: String = #function, line: Int = #line) {
        write(level: .error, message: message, data: data, screen: screen, file: file, function: function, line: line)
    }

    /// Call this explicitly at any `guard let` / `guard` failure site where
    /// you'd otherwise silently `return` — makes silent early-exits visible.
    func guardFailure(_ message: String, data: [String: Any]? = nil, screen: String? = nil,
                       file: String = #fileID, function: String = #function, line: Int = #line) {
        write(level: .guardFailure, message: message, data: data, screen: screen, file: file, function: function, line: line)
    }

    /// Call from a view's `.onAppear` to track screen opens. Also updates
    /// `currentScreen`, so every subsequent log (API calls, reader events,
    /// errors, etc.) is automatically tagged with it until the next screen.
    func screen(_ name: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        currentScreen = name
        write(level: .screen, message: "\(name) appeared", screen: name, file: file, function: function, line: line)
    }

    func navigation(from: String, to: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        currentScreen = to
        write(level: .navigation, message: "\(from) → \(to)", data: ["from": from, "to": to], screen: to, file: file, function: function, line: line)
    }

    /// Logs an outgoing request. `body` must already be redacted by the
    /// caller — never pass raw PAN/track/SRED/ARQC/CVV/PIN here (see
    /// `LogRedaction`); the API call sites in this app already do this.
    func apiRequest(api: String, method: String, url: String, body: [String: Any]? = nil,
                     file: String = #fileID, function: String = #function, line: Int = #line) {
        var data: [String: Any] = ["api": api, "method": method, "url": url]
        if let body { data["body"] = body }
        write(level: .apiRequest, message: "\(method) \(api)", data: data, file: file, function: function, line: line)
    }

    func apiResponse(api: String, statusCode: Int?, body: [String: Any]? = nil, error: String? = nil,
                      file: String = #fileID, function: String = #function, line: Int = #line) {
        var data: [String: Any] = ["api": api]
        if let statusCode { data["statusCode"] = statusCode }
        if let body { data["body"] = body }
        if let error { data["error"] = error }
        write(level: .apiResponse, message: "\(api) response", data: data, file: file, function: function, line: line)
    }

    /// Reader/hardware events (connect, disconnect, card read, errors). Never
    /// pass raw card data — pass masked previews (see `LogRedaction`) or
    /// metadata only (entry mode, lengths, KSN present/absent).
    func reader(_ event: String, data: [String: Any]? = nil,
                file: String = #fileID, function: String = #function, line: Int = #line) {
        write(level: .reader, message: event, data: data, file: file, function: function, line: line)
    }

    // MARK: - Core write

    private func write(level: LogLevel, message: String, data: [String: Any]? = nil, screen: String? = nil,
                        file: String, function: String, line: Int) {
        // Always resolve to a concrete screen name — falls back to whatever
        // screen was last reported, so this field is never missing in Firestore.
        let screen = screen ?? currentScreen

        #if DEBUG
        var consoleLine = "📋 [\(level.rawValue)] \(screen) \(function):\(line) — \(message)"
        // Print the full data payload too (pretty JSON) so EVERYTHING shows in the
        // Xcode console — reader fields, request bodies, responses, etc.
        if let data, !data.isEmpty {
            if JSONSerialization.isValidJSONObject(data),
               let json = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: json, encoding: .utf8) {
                consoleLine += "\n\(str)"
            } else {
                consoleLine += "\n\(data)"
            }
        }
        print(consoleLine)
        #endif

        LocalLogStore.shared.append(localLine(level: level, message: message, screen: screen, file: file, function: function, line: line, data: data))

        // Breadcrumb for every log line, so a crash report shows what led up
        // to it even if Firestore couldn't be reached at the time.
        Crashlytics.crashlytics().log("[\(level.rawValue)] \(function):\(line) — \(message)")

        // Errors/guard-failures are also recorded as non-fatals, so they show
        // up in the Crashlytics dashboard even when the app doesn't crash.
        if level == .error || level == .guardFailure {
            let nsError = NSError(
                domain: "MrFor.\(level.rawValue)",
                code: line,
                userInfo: [NSLocalizedDescriptionKey: "\(function): \(message)"]
            )
            Crashlytics.crashlytics().record(error: nsError)
        }

        guard let db else { return }

        var payload: [String: Any] = [
            "timestamp": FieldValue.serverTimestamp(),
            "level": level.rawValue,
            "screen": screen,
            "file": file,
            "function": function,
            "line": line,
            "message": message,
        ]
        if let currentPaymentId { payload["paymentId"] = currentPaymentId }
        if let data, JSONSerialization.isValidJSONObject(data) {
            payload["data"] = data
        }

        db.collection(sessionCollection).document(sessionId).collection("logs").addDocument(data: payload) { error in
            Self.logFirestoreErrorIfNeeded(error, context: "write(\(level.rawValue))")
        }
    }

    /// Surfaces Firestore write failures (e.g. permission-denied because
    /// security rules haven't been opened up yet) to the local console only —
    /// deliberately does not re-enter `write()` to avoid a feedback loop.
    private static func logFirestoreErrorIfNeeded(_ error: Error?, context: String) {
        #if DEBUG
        if let error {
            print("⚠️ AppLogger Firestore write failed [\(context)]: \(error.localizedDescription)")
        }
        #endif
    }

    private func localLine(level: LogLevel, message: String, screen: String, file: String, function: String, line: Int, data: [String: Any]?) -> String {
        var dict: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "sessionId": sessionId,
            "level": level.rawValue,
            "screen": screen,
            "file": file,
            "function": function,
            "line": line,
            "message": message,
        ]
        if let currentPaymentId { dict["paymentId"] = currentPaymentId }
        if let data, JSONSerialization.isValidJSONObject(data) { dict["data"] = data }

        guard JSONSerialization.isValidJSONObject(dict),
              let json = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: json, encoding: .utf8) else {
            return "\(level.rawValue): \(message)"
        }
        return string
    }
}
