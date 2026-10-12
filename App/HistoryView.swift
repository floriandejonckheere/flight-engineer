import Charts
import FlightEngineerKit
import SwiftUI

/// Credits used per day (one month at a time), week or month, as a chart and a table.
struct HistoryView: View {
    let monitor: UsageMonitor
    @State private var period = HistoryPeriod.day
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)!
    @State private var hoveredDate: Date?

    private let calendar = Calendar.current

    var body: some View {
        let allUsage = monitor.dailyUsage.grouped(by: period)
        let usage = period == .day ? allUsage.filter { $0.start >= month.start && $0.start < month.end } : allUsage

        VStack(alignment: .leading, spacing: 12) {
            Picker("Period", selection: $period) {
                ForEach(HistoryPeriod.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if period == .day {
                monthNavigation(firstDay: allUsage.first?.start)
            }

            if allUsage.isEmpty {
                ContentUnavailableView("No History", systemImage: "chart.bar", description: Text("Usage is recorded on every refresh."))
            } else {
                chart(usage)
                    .frame(height: 180)

                if usage.contains(where: \.isEstimated) {
                    Text("Estimated usage is spread evenly over the days without snapshots, e.g. before Flight Engineer was installed or while it was not running.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Table(usage.reversed()) {
                    TableColumn(period.title) { entry in
                        Text(label(for: entry))
                            .foregroundStyle(entry.isWorkingDay ? .primary : .secondary)
                    }
                    TableColumn("Credits") { entry in
                        Text(entry.credits.credits).monospacedDigit()
                            .foregroundStyle(entry.isEstimated ? .secondary : .primary)
                    }
                    TableColumn("") { entry in
                        if let note = estimateNote(for: entry) {
                            Text(note).foregroundStyle(.secondary)
                        }
                    }
                    .alignment(.trailing)
                }
            }
        }
        .padding()
        .frame(minWidth: 480, idealWidth: 560, minHeight: 420, idealHeight: 560)
    }

    private func monthNavigation(firstDay: Date?) -> some View {
        HStack {
            Button("Previous Month", systemImage: "chevron.left") { moveMonth(by: -1) }
                .disabled(firstDay.map { $0 >= month.start } ?? true)
            Spacer()
            Text(month.start.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()
            Button("Next Month", systemImage: "chevron.right") { moveMonth(by: 1) }
                .disabled(month.contains(.now))
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    private func chart(_ usage: [PeriodUsage]) -> some View {
        let hovered = hoveredDate.flatMap { date in
            usage.first { calendar.isDate($0.start, equalTo: date, toGranularity: period.component) }
        }

        return Chart {
            ForEach(usage) { entry in
                BarMark(x: .value(period.title, entry.start, unit: period.component), y: .value("Credits", entry.credits))
                    .foregroundStyle(entry.isWorkingDay ? Color.accentColor.gradient : Color.gray.gradient)
                    .opacity((hovered == nil || hovered == entry ? 1 : 0.5) * (period == .day && entry.isEstimated ? 0.4 : 1))
                    .cornerRadius(2)
            }

            if let hovered {
                RuleMark(x: .value(period.title, hovered.start, unit: period.component))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        tooltip(for: hovered)
                    }
            }
        }
        .chartXScale(domain: period == .day ? month.start...month.end : xDomain(usage))
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case let .active(location):
                            let plotOrigin = proxy.plotFrame.map { geometry[$0].origin } ?? .zero
                            hoveredDate = proxy.value(atX: location.x - plotOrigin.x, as: Date.self)
                        case .ended:
                            hoveredDate = nil
                        }
                    }
            }
        }
    }

    private func tooltip(for entry: PeriodUsage) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label(for: entry))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(entry.credits.credits) credits")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
            if let note = estimateNote(for: entry) {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    /// Spans whole weeks or months, so the first and last bars are not cut in half.
    private func xDomain(_ usage: [PeriodUsage]) -> ClosedRange<Date> {
        guard let first = usage.first?.start, let last = usage.last?.start,
              let end = calendar.dateInterval(of: period.component, for: last)?.end
        else { return month.start...month.end }
        return first...end
    }

    private func moveMonth(by value: Int) {
        guard let start = calendar.date(byAdding: .month, value: value, to: month.start),
              let interval = calendar.dateInterval(of: .month, for: start)
        else { return }
        month = interval
    }

    private func estimateNote(for entry: PeriodUsage) -> String? {
        guard entry.isEstimated else { return nil }
        return period == .day ? "Estimated" : "Includes estimates"
    }

    private func label(for entry: PeriodUsage) -> String {
        switch period {
        case .day: entry.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
        case .week: "Week of \(entry.start.formatted(.dateTime.month(.abbreviated).day().year()))"
        case .month: entry.start.formatted(.dateTime.month(.wide).year())
        }
    }
}
