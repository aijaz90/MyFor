//
//  AppLogModels.swift
//  MrFor
//
//  Shared small types for the logging system: the log categories that show up
//  as `level` in Firestore, device/app metadata attached to every session, and
//  helpers for keeping card data out of anything that leaves the device.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Category of a single log line. The raw value is exactly what's stored as
/// `level` in Firestore (`RealReaderLogs/{sessionId}/logs`), so filtering by
/// level in the Firebase console lines up with these strings.
enum LogLevel: String, Codable {
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    case guardFailure = "GuardFailure"
    case screen = "Screen"
    case navigation = "Navigation"
    case apiRequest = "APIRequest"
    case apiResponse = "APIResponse"
    case reader = "Reader"
}

/// Static app/device facts attached to every session so a report from a
/// tester's phone (different country, different build) is self-describing
/// without needing to ask them what device/version they're on.
enum DeviceContext {
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    static var osVersion: String {
        #if canImport(UIKit)
        return "iOS \(UIDevice.current.systemVersion)"
        #else
        return "-"
        #endif
    }

    /// Marketing-ish device name isn't available on-device without a lookup
    /// table, so this is the raw hardware identifier (e.g. "iPhone15,2") —
    /// still enough to identify the model precisely.
    static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier.isEmpty ? "-" : identifier
    }

    /// The user-assigned device name (e.g. "Aijaz's iPhone"), useful for
    /// telling testers' devices apart at a glance.
    static var deviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "-"
        #endif
    }
}

/// Keeps anything PCI-scoped out of remote/persistent logs. The reader flow
/// already prints full encrypted blocks to the local Xcode console for
/// debugging (see `logCardData` in ReaderModels.swift) — that's fine, it's
/// DEBUG-only and never leaves the machine. Nothing that goes to Firestore or
/// the on-device log mirror should carry a full PAN, track, SRED/ARQC block,
/// CVV, or PIN. Use these helpers to build safe previews instead.
enum LogRedaction {
    /// Masks everything but the last `keep` characters — good for previews of
    /// values that shouldn't be persisted in full (KSNs, serials if desired).
    static func maskKeepingLast(_ value: String, keep: Int = 4) -> String {
        guard value.count > keep else { return String(repeating: "•", count: value.count) }
        let tail = value.suffix(keep)
        return String(repeating: "•", count: value.count - keep) + tail
    }

    /// A short, non-reversible-enough preview of a hex blob (SRED/ARQC/track2)
    /// — just its length and a short prefix, enough to notice "this looks
    /// empty/truncated" without persisting the actual encrypted card data.
    static func hexPreview(_ hex: String, prefixLength: Int = 6) -> String {
        guard !hex.isEmpty else { return "<empty>" }
        return "\(hex.prefix(prefixLength))…(\(hex.count) chars)"
    }

    /// Card brand + last 4 from a track2 hex string, e.g. "VISA •••• 1111".
    /// Falls back to "masked" if track2 can't be parsed.
    static func cardPreview(track2Hex: String, cardType: String) -> String {
        guard let ascii = hexToASCII(track2Hex) else {
            return cardType.isEmpty ? "masked" : cardType
        }
        let digits = ascii.drop { !$0.isNumber }
        let pan = digits.prefix { $0 != "=" && $0 != "D" }
        let last4 = pan.suffix(4)
        let brand = cardType.isEmpty ? "Card" : cardType
        return last4.isEmpty ? brand : "\(brand) •••• \(last4)"
    }

    /// Local, single-purpose hex → ASCII decode so this file doesn't need a
    /// shared `Data` extension (avoids clashing with the reader's own private
    /// hex helpers in MagTekReader.swift).
    private static func hexToASCII(_ hex: String) -> String? {
        let chars = hex.filter { $0.isHexDigit }
        guard !chars.isEmpty else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(chars.count / 2)
        var idx = chars.startIndex
        while idx < chars.endIndex, chars.index(after: idx) < chars.endIndex {
            let next = chars.index(idx, offsetBy: 2)
            if let byte = UInt8(chars[idx..<next], radix: 16) { bytes.append(byte) }
            idx = next
        }
        guard let s = String(bytes: bytes, encoding: .ascii), s.allSatisfy({ $0.isASCII }) else { return nil }
        return s
    }
}

