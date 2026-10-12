import FlightEngineerKit
import SwiftUI

struct SettingsView: View {
    let monitor: UsageMonitor
    @Environment(\.openWindow) private var openWindow

    @AppStorage(MenuBarPreferences.showsUsedKey) private var showsUsed = false
    @AppStorage(MenuBarPreferences.usedFormatKey) private var usedFormat = UsageFormat.percentage
    @AppStorage(MenuBarPreferences.showsProjectedKey) private var showsProjected = false
    @AppStorage(MenuBarPreferences.projectedFormatKey) private var projectedFormat = UsageFormat.percentage

    var body: some View {
        Form {
            Section("GitHub Account") {
                if monitor.state.status == .signedOut {
                    LabeledContent("Not signed in") {
                        Button("Sign In…") {
                            openWindow(id: FlightEngineerApp.signInWindowID)
                        }
                    }
                } else {
                    LabeledContent(monitor.state.plan.map { "Signed in (\($0) plan)" } ?? "Signed in") {
                        Button("Sign Out") {
                            Task { await monitor.signOut() }
                        }
                    }
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: Binding(get: { monitor.launchesAtLogin }, set: { monitor.setLaunchesAtLogin($0) }))
            }

            Section("Menu Bar") {
                usageRow("Show current usage", isOn: $showsUsed, format: $usedFormat)
                usageRow("Show projected usage", isOn: $showsProjected, format: $projectedFormat)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize()
    }

    private func usageRow(_ title: String, isOn: Binding<Bool>, format: Binding<UsageFormat>) -> some View {
        HStack {
            Toggle(title, isOn: isOn)
            Spacer()
            Picker(title, selection: format) {
                ForEach(UsageFormat.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            .disabled(!isOn.wrappedValue)
        }
    }
}
