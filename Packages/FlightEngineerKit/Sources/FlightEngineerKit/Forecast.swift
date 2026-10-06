import Foundation

/// A single observation of the Copilot credit counter.
public struct UsageSnapshot: Codable, Equatable, Sendable {
    public var date: Date
    public var used: Double
    public var total: Double
    public var resetDate: Date

    public init(date: Date, used: Double, total: Double, resetDate: Date) {
        self.date = date
        self.used = used
        self.total = total
        self.resetDate = resetDate
    }
}

/// Credits consumed on a single working day.
public struct DailyUsage: Codable, Equatable, Sendable {
    public var day: Date
    public var credits: Double

    public init(day: Date, credits: Double) {
        self.day = day
        self.credits = credits
    }
}

public enum Outlook: String, Codable, Sendable {
    /// Projected usage stays comfortably below the quota.
    case creditsLeft
    /// Projected usage ends up close to the quota.
    case reachingQuota
    /// Projected usage exceeds the quota before it resets.
    case shortage
}

public struct Forecast: Codable, Equatable, Sendable {
    /// Weighted average of credits consumed per working day.
    public var dailyRate: Double
    /// Credits expected to be used by the time the quota resets.
    public var projectedUsage: Double
    /// Quota minus projected usage; negative when credits run short.
    public var projectedBalance: Double
    /// Working days left in the period, including today.
    public var remainingWorkingDays: Int
    public var outlook: Outlook
    /// The working day on which the credits are expected to run out, if they do.
    public var depletionDay: Date?
    /// Recent working days, oldest first, including today.
    public var history: [DailyUsage]
}

/// Projects Copilot credit usage until the quota resets, based on a weighted
/// average of the most recent working days (weekends are ignored).
public struct Forecaster: Sendable {
    public var calendar: Calendar
    /// Number of past working days taken into account for the daily rate.
    public var window: Int
    /// Fraction of the quota above which the outlook becomes `reachingQuota`.
    public var reachingQuotaThreshold: Double
    /// Number of working days returned in `Forecast.history`.
    public var historyLength: Int

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    public init(calendar: Calendar = .current, window: Int = 5, reachingQuotaThreshold: Double = 0.9, historyLength: Int = 10) {
        self.calendar = calendar
        self.window = window
        self.reachingQuotaThreshold = reachingQuotaThreshold
        self.historyLength = historyLength
    }

    public func forecast(snapshots: [UsageSnapshot], now: Date) -> Forecast? {
        let snapshots = snapshots.filter { $0.date <= now }
        guard let latest = snapshots.max(by: { $0.date < $1.date }), latest.total > 0 else { return nil }

        let today = calendar.startOfDay(for: now)
        let samples = dailySamples(from: snapshots)

        let pastSamples = samples.filter { $0.day < today }.suffix(window)
        let usedToday = samples.first { $0.day == today }?.credits ?? 0
        let dailyRate = pastSamples.isEmpty ? usedToday : weightedAverage(pastSamples.map(\.credits))

        let resetDay = localDay(matchingUTCDayOf: latest.resetDate)
        let isTodayWorking = isWorkingDay(today) && today < resetDay
        let futureDays = workingDays(after: today, before: resetDay)
        let todayRemaining = isTodayWorking ? max(0, dailyRate - usedToday) : 0
        let projectedUsage = latest.used + todayRemaining + dailyRate * Double(futureDays.count)

        let outlook: Outlook
        if projectedUsage > latest.total {
            outlook = .shortage
        } else if projectedUsage >= latest.total * reachingQuotaThreshold {
            outlook = .reachingQuota
        } else {
            outlook = .creditsLeft
        }

        return Forecast(
            dailyRate: dailyRate,
            projectedUsage: projectedUsage,
            projectedBalance: latest.total - projectedUsage,
            remainingWorkingDays: futureDays.count + (isTodayWorking ? 1 : 0),
            outlook: outlook,
            depletionDay: outlook == .shortage
                ? depletionDay(balance: latest.total - latest.used, today: today, todayBudget: todayRemaining, futureDays: futureDays, dailyRate: dailyRate)
                : nil,
            history: Array(samples.filter { $0.day <= today }.suffix(historyLength))
        )
    }

    /// Credits consumed per working day, oldest first. Usage between two snapshots
    /// is spread evenly over the working days in between; usage on non-working days
    /// is attributed to the next working day.
    func dailySamples(from snapshots: [UsageSnapshot]) -> [DailyUsage] {
        var samples: [Date: Double] = [:]

        for (resetDate, periodSnapshots) in Dictionary(grouping: snapshots, by: \.resetDate) {
            guard let periodStart = Self.utcCalendar.date(byAdding: .month, value: -1, to: resetDate) else { continue }

            let firstDay = localDay(matchingUTCDayOf: periodStart)
            var endOfDay: [Date: Double] = [:]
            for snapshot in periodSnapshots {
                let day = max(firstDay, calendar.startOfDay(for: snapshot.date))
                endOfDay[day] = max(endOfDay[day] ?? 0, snapshot.used)
            }

            var previousDay = calendar.date(byAdding: .day, value: -1, to: firstDay)!
            var previousUsed = 0.0
            var carry = 0.0
            for (day, used) in endOfDay.sorted(by: { $0.key < $1.key }) {
                let delta = max(0, used - previousUsed) + carry
                let days = workingDays(after: previousDay, before: calendar.date(byAdding: .day, value: 1, to: day)!)
                if days.isEmpty {
                    carry = delta
                } else {
                    carry = 0
                    for workingDay in days {
                        samples[workingDay, default: 0] += delta / Double(days.count)
                    }
                }
                previousDay = day
                previousUsed = used
            }
        }

        return samples
            .map { DailyUsage(day: $0.key, credits: $0.value) }
            .sorted { $0.day < $1.day }
    }

    func isWorkingDay(_ day: Date) -> Bool {
        !calendar.isDateInWeekend(day)
    }

    /// Working days strictly between `start` and `end` (both start of day).
    func workingDays(after start: Date, before end: Date) -> [Date] {
        var days: [Date] = []
        var day = calendar.date(byAdding: .day, value: 1, to: start)!
        while day < end {
            if isWorkingDay(day) { days.append(day) }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return days
    }

    /// GitHub resets quotas at midnight UTC; the local day carrying the same date
    /// is used as the boundary so the period never spills over into another day.
    func localDay(matchingUTCDayOf date: Date) -> Date {
        let components = Self.utcCalendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: date)
    }

    /// Linearly weighted average where the most recent value weighs the most.
    func weightedAverage(_ values: [Double]) -> Double {
        let weights = (1...values.count).map(Double.init)
        let weightedSum = zip(values, weights).map(*).reduce(0, +)
        return weightedSum / weights.reduce(0, +)
    }

    private func depletionDay(balance: Double, today: Date, todayBudget: Double, futureDays: [Date], dailyRate: Double) -> Date? {
        if balance <= todayBudget { return today }

        var balance = balance - todayBudget
        for day in futureDays {
            if balance <= dailyRate { return day }
            balance -= dailyRate
        }
        return nil
    }
}
