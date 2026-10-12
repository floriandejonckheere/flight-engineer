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

    @Environment(\.displayScale) private var displayScale

    /// The menu bar lays out an icon and a title independently, which leaves
    /// the symbol smaller than and misaligned with the text. Rendering both
    /// into a single template image keeps them aligned on a shared baseline.
    var body: some View {
        if let text, let image = render(text) {
            Image(nsImage: image)
        } else {
            Image(systemName: Self.symbolName)
        }
    }

    private static let symbolName = "gauge.with.dots.needle.67percent"

    @MainActor
    private func render(_ text: String) -> NSImage? {
        let content = HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: Self.symbolName)
            Text(text).monospacedDigit()
        }
        .font(Font(NSFont.menuBarFont(ofSize: 0)))

        let renderer = ImageRenderer(content: content)
        renderer.scale = displayScale
        let image = renderer.nsImage
        image?.isTemplate = true
        return image
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
