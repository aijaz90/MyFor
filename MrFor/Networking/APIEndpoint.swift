//
//  APIEndpoint.swift
//  MrFor
//
//  Single source of truth for the app's remote URLs. Endpoints are declared as
//  enum cases with their method + path, and each builds its own URLRequest, so
//  URLs are never hand-assembled at call sites.
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// Backend hosts. Kept separate from endpoints so the base URL is defined once.
enum APIEnvironment {
    /// MMS Kiosk API (Azure) — used for real DynaFlex II Go reader transactions.
    /// Built without force-unwrapping; the `??` fallback is unreachable for this
    /// valid literal but keeps the type non-optional and crash-free.
    static let mmsBaseURL = URL(string: "https://mmsapiapp-dev.azurewebsites.net")
        ?? URL(fileURLWithPath: "/")
}

/// Every remote endpoint the app calls. Add a case here instead of building a
/// URL inline anywhere else.
enum APIEndpoint {
    /// POST a DynaFlex reader payment to the MMS Kiosk API.
    case dynaFlexPayment

    var baseURL: URL {
        switch self {
        case .dynaFlexPayment: return APIEnvironment.mmsBaseURL
        }
    }

    var method: HTTPMethod {
        switch self {
        case .dynaFlexPayment: return .post
        }
    }

    var path: String {
        switch self {
        case .dynaFlexPayment: return "/api/Kiosk/dynaflex/payment"
        }
    }

    /// Fully-qualified URL (base has no trailing slash, path has a leading slash).
    var url: URL {
        URL(string: baseURL.absoluteString + path) ?? baseURL
    }

    /// Builds a ready-to-send request.
    ///
    /// NOTE: server-side Authorization is temporarily disabled. When it's turned
    /// back on, add the token in this one place and every endpoint picks it up:
    ///
    ///     if let token = AuthSession.shared.accessToken {
    ///         request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    ///     }
    func makeRequest(body: Data? = nil, timeout: TimeInterval = 30) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        return request
    }
}
