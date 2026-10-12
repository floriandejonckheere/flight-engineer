import FlightEngineerKit
import SwiftUI

/// `UserDefaults` keys of the usage shown next to the menu bar icon.
enum MenuBarPreferences {
    static let showsUsedKey = "menuBar.showsUsed"
    static let usedFormatKey = "menuBar.usedFormat"
    static let showsProjectedKey = "menuBar.showsProjected"
    static let projectedFormatKey = "menuBar.projectedFormat"
}

/// Menu bar icon, followed by the current and/or projected usage when enabled
/// in the settings, e.g. "42% → 98%".
struct MenuBarLabel: View {
    let monitor: UsageMonitor

    @AppStorage(MenuBarPreferences.showsUsedKey) private var showsUsed = false
    @AppStorage(MenuBarPreferences.usedFormatKey) private var usedFormat = UsageFormat.percentage
    @AppStorage(MenuBarPreferences.showsProjectedKey) private var showsProjected = false
    @AppStorage(MenuBarPreferences.projectedFormatKey) private var projectedFormat = UsageFormat.percentage

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.with.dots.needle.67percent")
            if let text {
                Text(text).monospacedDigit()
            }
        }
    }

    private var text: String? {
        guard let latest = monitor.state.latest else { return nil }

        var parts: [String] = []
        if showsUsed {
            parts.append(usedFormat.format(latest.used, total: latest.total))
        }
        if showsProjected, let forecast = monitor.forecast {
            parts.append(projectedFormat.format(forecast.projectedUsage, total: latest.total))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " → ")
    }
}
