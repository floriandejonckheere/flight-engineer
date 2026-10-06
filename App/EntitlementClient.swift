import Foundation
import FlightEngineerKit

enum EntitlementError: LocalizedError {
    case signedOut
    case http(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .signedOut: "Not signed in to GitHub"
        case let .http(code): "GitHub returned HTTP \(code)"
        case .invalidResponse: "Unexpected response from GitHub"
        }
    }
}

struct EntitlementClient {
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        return URLSession(configuration: configuration)
    }()

    func fetch(cookies: [HTTPCookie]) async throws -> Entitlement {
        var request = URLRequest(url: GitHubSession.entitlementURL)
        request.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: cookies)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw EntitlementError.invalidResponse }

        switch response.statusCode {
        case 200:
            if response.url?.path.hasPrefix("/login") == true { throw EntitlementError.signedOut }
            do {
                return try Entitlement.decode(from: data)
            } catch {
                let isJSON = response.value(forHTTPHeaderField: "Content-Type")?.contains("json") ?? false
                throw isJSON ? EntitlementError.invalidResponse : EntitlementError.signedOut
            }
        case 401, 403, 404:
            throw EntitlementError.signedOut
        default:
            throw EntitlementError.http(response.statusCode)
        }
    }
}
