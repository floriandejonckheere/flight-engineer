import FlightEngineerKit
import SwiftUI

@main
struct FlightEngineerApp: App {
    static let signInWindowID = "sign-in"
    static let settingsWindowID = "settings"

    @State private var monitor = UsageMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(monitor: monitor)
        } label: {
            MenuBarLabel(monitor: monitor)
                .task { monitor.start() }
        }

        Window("Sign in to GitHub", id: Self.signInWindowID) {
            SignInView(monitor: monitor)
        }
        .windowResizability(.contentSize)

        Window("Flight Engineer Settings", id: Self.settingsWindowID) {
            SettingsView(monitor: monitor)
        }
        .windowResizability(.contentSize)
    }
}

private struct MenuContent: View {
    let monitor: UsageMonitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            switch monitor.state.status {
            case .signedOut:
                Text("Not signed in to GitHub")
            case let .failed(message):
                Text("⚠︎ \(message)")
                usage
            case .ok:
                usage
            }

            if let lastSuccess = monitor.state.lastSuccess {
                Text("Updated \(lastSuccess.formatted(.relative(presentation: .named)))")
            }
        }

        Divider()

        Button(monitor.isRefreshing ? "Refreshing…" : "Refresh Now") {
            Task { await monitor.refresh() }
        }
        .keyboardShortcut("r")
        .disabled(monitor.isRefreshing)

        if monitor.state.status == .signedOut {
            Button("Sign In…") {
                open(FlightEngineerApp.signInWindowID)
            }
        }

        Button("Settings…") {
            open(FlightEngineerApp.settingsWindowID)
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Flight Engineer") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func open(_ windowID: String) {
        NSApp.activate()
        openWindow(id: windowID)
    }

    @ViewBuilder
    private var usage: some View {
        if let latest = monitor.state.latest {
            Text("\(latest.used.credits) of \(latest.total.credits) credits used")
            if let forecast = monitor.forecast {
                Text("\(forecast.outlook.title): \(forecast.summary(resetDate: latest.resetDate))")
                Text("\(forecast.dailyRate.credits) credits per working day")
            }
        }
    }
}
