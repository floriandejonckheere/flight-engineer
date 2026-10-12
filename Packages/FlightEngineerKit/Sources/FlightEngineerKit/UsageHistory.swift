import Foundation

/// Granularity of the usage history.
public enum HistoryPeriod: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month

    public var id: Self { self }

    public var title: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        }
    }

    public var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
    }
}

/// Credits consumed in a single day, week or month.
public struct PeriodUsage: Equatable, Identifiable, Sendable {
    public var start: Date
    public var credits: Double
    /// False only for non-working days in the daily history.
    public var isWorkingDay: Bool

    public var id: Date { start }

    public init(start: Date, credits: Double, isWorkingDay: Bool = true) {
        self.start = start
        self.credits = credits
        self.isWorkingDay = isWorkingDay
    }
}

public extension [DailyUsage] {
    /// Sums the daily usage per `period`, oldest first.
    func grouped(by period: HistoryPeriod, calendar: Calendar = .current) -> [PeriodUsage] {
        guard period != .day else {
            return map { PeriodUsage(start: $0.day, credits: $0.credits, isWorkingDay: $0.isWorkingDay) }
        }

        let totals = Dictionary(grouping: self) { calendar.dateInterval(of: period.component, for: $0.day)!.start }
            .mapValues { $0.reduce(0) { $0 + $1.credits } }
        return totals
            .map { PeriodUsage(start: $0.key, credits: $0.value) }
            .sorted { $0.start < $1.start }
    }
}
