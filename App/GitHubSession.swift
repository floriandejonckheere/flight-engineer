import Foundation
import WebKit

/// GitHub web session, shared with the sign-in web view through the default
/// WebKit data store so cookies persist across launches.
@MainActor
enum GitHubSession {
    nonisolated static let signInURL = URL(string: "https://github.com/login")!
    nonisolated static let entitlementURL = URL(string: "https://github.com/github-copilot/chat/entitlement")!

    private static var dataStore: WKWebsiteDataStore { .default() }

    /// WebKit only loads persisted cookies once a web view exists in the process.
    private static let cookieLoader = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

    static func cookies() async -> [HTTPCookie] {
        _ = cookieLoader
        return await dataStore.httpCookieStore.allCookies().filter { $0.domain.hasSuffix("github.com") }
    }

    static func isSignedIn() async -> Bool {
        await cookies().contains { $0.name == "user_session" && ($0.expiresDate ?? .distantFuture) > .now }
    }

    static func signOut() async {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await dataStore.dataRecords(ofTypes: types).filter { $0.displayName.contains("github") }
        await dataStore.removeData(ofTypes: types, for: records)
    }
}
