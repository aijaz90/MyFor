//
//  ForteConfig.swift
//  MrFor
//
//  Points the app at the eventExplore backend. There are deliberately no Forte
//  credentials here, and none should ever be added: the API Secure Key can move
//  money, and anything shipped in an .ipa is readable. The app talks only to our
//  own server, which holds the credentials.
//
//  The active backend is chosen in Server settings: "Local" (your localhost
//  eventExplore) or "Production" (your deployed server). Both expose the same
//  endpoints; only the base URL differs.
//

import Foundation

enum ForteConfig {
    enum Environment: String, CaseIterable {
        case local
        case production

        var title: String { self == .local ? "Local" : "Production" }
        var subtitle: String { self == .local ? "Your machine / LAN" : "Deployed server" }
        var symbol: String { self == .local ? "laptopcomputer" : "cloud" }
    }

    // UserDefaults keys, shared with ServerSettingsView (@AppStorage).
    static let envKey = "backend_env"
    static let localURLKey = "backend_local_url"
    static let prodURLKey = "backend_prod_url"

    // Defaults. Local works on the Simulator as-is; on a physical device use your
    // Mac's LAN address (e.g. http://192.168.1.42:3000). Production defaults to
    // the deployed Azure backend, so a fresh install talks to it — not localhost.
    static let defaultLocalURL = "http://localhost:3000"
    static let defaultProdURL = "https://mmsapiapp-dev.azurewebsites.net"

    static var environment: Environment {
        Environment(rawValue: UserDefaults.standard.string(forKey: envKey) ?? "") ?? .production
    }

    /// Crash-free fallback (the `??` branch is unreachable for this valid literal).
    private static let fallbackURL = URL(string: "http://localhost:3000") ?? URL(fileURLWithPath: "/")

    /// The active base URL, resolved live so a change in Settings takes effect at once.
    static var backendBaseURL: URL {
        let raw: String
        switch environment {
        case .local:      raw = stored(localURLKey, fallback: defaultLocalURL)
        case .production: raw = stored(prodURLKey, fallback: defaultProdURL)
        }
        return URL(string: raw) ?? fallbackURL
    }

    static func endpoint(_ path: String) -> URL {
        backendBaseURL.appendingPathComponent(path)
    }

    private static func stored(_ key: String, fallback: String) -> String {
        let v = UserDefaults.standard.string(forKey: key)?.trimmingCharacters(in: .whitespaces)
        if let v, !v.isEmpty { return v }
        return fallback
    }
}

/// How a charge attempt ended.
enum PaymentOutcome: Equatable {
    case approved(transactionID: String?, authCode: String?)
    case declined(message: String)
    case failed(message: String)
}
