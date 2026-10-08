import Charts
import FlightEngineerKit
import SwiftUI
import WidgetKit

@main
struct FlightEngineerWidgetBundle: WidgetBundle {
    var body: some Widget {
        CreditsWidget()
    }
}

struct CreditsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CreditsWidget", provider: Provider()) { entry in
            CreditsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Copilot Credits")
        .description("Monitors your GitHub Copilot AI credits and forecasts whether they will last the month.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let state: SharedState
    let forecast: Forecast?
    let isStale: Bool

    init(date: Date, state: SharedState) {
        self.date = date
        self.state = state
        self.forecast = Forecaster().forecast(snapshots: state.snapshots, now: date)
        self.isStale = state.isStale(at: date)
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, state: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let state = SharedStore.load()
        completion(Entry(date: .now, state: context.isPreview && state.latest == nil ? .preview : state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date.now
        let entry = Entry(date: now, state: SharedStore.load())
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(15 * 60))))
    }
}

struct CreditsWidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let latest = entry.state.latest {
            switch family {
            case .systemMedium:
                HStack(spacing: 16) {
                    summary(latest)
                    details(latest)
                }
            default:
                summary(latest)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                header
                Spacer()
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Sign in to GitHub from the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.with.dots.needle.67percent")
            Text("Copilot")
            Spacer()
            if entry.isStale, let lastSuccess = entry.state.lastSuccess {
                Text(lastSuccess.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)))
                    .lineLimit(1)
            }
            if entry.state.status != .ok || entry.isStale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private func summary(_ latest: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            header

            Spacer(minLength: 0)

            Text(latest.used.credits)
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("of \(latest.total.credits) credits")
                .font(.caption)
                .foregroundStyle(.secondary)

            UsageBar(used: latest.used, projected: entry.forecast?.projectedUsage, total: latest.total, tint: tint)
                .frame(height: 6)
                .padding(.vertical, 2)

            if let forecast = entry.forecast {
                Label(forecast.outlook.title, systemImage: forecast.outlook.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(forecast.summary(resetDate: latest.resetDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func details(_ latest: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let forecast = entry.forecast {
                Chart(forecast.history, id: \.day) { usage in
                    BarMark(x: .value("Day", usage.day.formatted(.dateTime.month().day())), y: .value("Credits", usage.credits))
                        .foregroundStyle(tint.gradient)
                        .cornerRadius(2)
                    RuleMark(y: .value("Average", forecast.dailyRate))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)

                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 2) {
                    row("Per day", forecast.dailyRate.credits)
                    row("Projected", forecast.projectedUsage.credits)
                    row("Days left", "\(forecast.remainingWorkingDays)")
                }
                .font(.caption2)
            }
            Text("Resets \(latest.resetDate.formatted(.dateTime.month(.abbreviated).day()))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value).monospacedDigit().fontWeight(.medium)
        }
    }

    private var tint: Color {
        switch entry.forecast?.outlook {
        case .creditsLeft: .green
        case .reachingQuota: .blue
        case .shortage: .red
        case nil: .secondary
        }
    }
}

/// Horizontal bar showing used credits, with a lighter extension up to the projected usage.
struct UsageBar: View {
    let used: Double
    let projected: Double?
    let total: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                if let projected {
                    Capsule().fill(tint.opacity(0.35))
                        .frame(width: width * fraction(projected))
                }
                Capsule().fill(tint)
                    .frame(width: width * fraction(used))
            }
        }
    }

    private func fraction(_ value: Double) -> Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, value / total))
    }
}

extension SharedState {
    static var preview: SharedState {
        let calendar = Calendar.current
        let resetDate = calendar.date(byAdding: .day, value: 20, to: .now)!
        let snapshots = (0..<8).reversed().map { daysAgo in
            UsageSnapshot(
                date: calendar.date(byAdding: .day, value: -daysAgo, to: .now)!,
                used: Double(12_000 - daysAgo * 1_100),
                total: 30_000,
                resetDate: resetDate
            )
        }
        return SharedState(status: .ok, lastSuccess: .now, snapshots: snapshots)
    }
}

#Preview(as: .systemMedium) {
    CreditsWidget()
} timeline: {
    Entry(date: .now, state: .preview)
}
