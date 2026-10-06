import SwiftUI
import WebKit

/// Shows the GitHub login page and closes once a session cookie is present.
struct SignInView: View {
    let monitor: UsageMonitor
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        GitHubWebView {
            dismissWindow(id: FlightEngineerApp.signInWindowID)
            Task { await monitor.refresh() }
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 640, idealHeight: 720)
    }
}

private struct GitHubWebView: NSViewRepresentable {
    let onSignIn: @MainActor () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSignIn: onSignIn)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: GitHubSession.signInURL))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onSignIn: @MainActor () -> Void
        private var signedIn = false

        init(onSignIn: @escaping @MainActor () -> Void) {
            self.onSignIn = onSignIn
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task {
                guard !signedIn, await GitHubSession.isSignedIn() else { return }
                signedIn = true
                onSignIn()
            }
        }
    }
}
