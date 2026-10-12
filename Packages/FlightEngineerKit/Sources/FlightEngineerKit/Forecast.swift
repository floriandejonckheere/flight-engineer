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

/// Credits consumed on a single day.
public struct DailyUsage: Codable, Equatable, Sendable {
    public var day: Date
    public var credits: Double
    /// Whether the day counts towards the daily rate; weekends do not.
    public var isWorkingDay: Bool
    /// Whether the credits are spread over several days because no snapshot
    /// was taken at the end of the previous day, rather than measured.
    public var isEstimated: Bool

    public init(day: Date, credits: Double, isWorkingDay: Bool, isEstimated: Bool = false) {
        self.day = day
        self.credits = credits
        self.isWorkingDay = isWorkingDay
        self.isEstimated = isEstimated
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
    /// Recent days, oldest first, including today and non-working days.
    public var history: [DailyUsage]
}

/// Projects Copilot credit usage until the quota resets, based on a weighted
/// average of the most recent working days (weekends are ignored). Recent days
/// weigh only slightly more, so a single heavy day does not dominate the forecast.
public struct Forecaster: Sendable {
    public var calendar: Calendar
    /// Number of past working days taken into account for the daily rate.
    public var window: Int
    /// Fraction of the quota above which the outlook becomes `reachingQuota`.
    public var reachingQuotaThreshold: Double
    /// Number of days returned in `Forecast.history`.
    public var historyLength: Int

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    public init(calendar: Calendar = .current, window: Int = 10, reachingQuotaThreshold: Double = 0.9, historyLength: Int = 14) {
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

        let pastCredits = pastCredits(from: samples, before: today)
        let usedToday = samples.first { $0.day == today }?.credits ?? 0
        let dailyRate = pastCredits.isEmpty ? usedToday : weightedAverage(pastCredits)

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
            history: Array(dailyUsage(from: samples, through: today).suffix(historyLength))
        )
    }

    /// Credits consumed on every day from the first snapshot through `now`,
    /// oldest first. Days without usage have zero credits.
    public func dailyUsage(snapshots: [UsageSnapshot], now: Date) -> [DailyUsage] {
        let snapshots = snapshots.filter { $0.date <= now }
        return dailyUsage(from: dailySamples(from: snapshots), through: calendar.startOfDay(for: now))
    }

    /// Credits consumed per day, oldest first. Usage between two snapshots is
    /// spread evenly over the working days in between and the day of the later
    /// snapshot, so non-working days only get usage when a snapshot was taken on them.
    /// Usage is measured only when the previous snapshot was taken the day before.
    func dailySamples(from snapshots: [UsageSnapshot]) -> [DailyUsage] {
        var samples: [Date: Double] = [:]
        var estimatedDays: Set<Date> = []

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
            for (day, used) in endOfDay.sorted(by: { $0.key < $1.key }) {
                let delta = max(0, used - previousUsed)
                let days = workingDays(after: previousDay, before: day) + [day]
                for spreadDay in days {
                    samples[spreadDay, default: 0] += delta / Double(days.count)
                }
                if calendar.date(byAdding: .day, value: 1, to: previousDay)! != day {
                    estimatedDays.formUnion(days)
                }
                previousDay = day
                previousUsed = used
            }
        }

        return samples
            .map { DailyUsage(day: $0.key, credits: $0.value, isWorkingDay: isWorkingDay($0.key), isEstimated: estimatedDays.contains($0.key)) }
            .sorted { $0.day < $1.day }
    }

    /// Every day from the first sample through `today`. Days without samples have
    /// zero credits and are estimated, as their usage ended up on a later day.
    func dailyUsage(from samples: [DailyUsage], through today: Date) -> [DailyUsage] {
        guard let firstDay = samples.first?.day else { return [] }

        let samplesByDay = Dictionary(samples.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        var days: [DailyUsage] = []
        var day = firstDay
        while day <= today {
            days.append(samplesByDay[day] ?? DailyUsage(day: day, credits: 0, isWorkingDay: isWorkingDay(day), isEstimated: true))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return days
    }

    /// Credits consumed on the last `window` working days before `today`, oldest
    /// first. Days without data are filled with the average of the known days;
    /// empty when none of the days are known.
    func pastCredits(from samples: [DailyUsage], before today: Date) -> [Double] {
        let days = workingDays(before: today, count: window)
        let known = Dictionary(samples.filter { days.contains($0.day) }.map { ($0.day, $0.credits) }, uniquingKeysWith: +)
        guard !known.isEmpty else { return [] }

        let average = known.values.reduce(0, +) / Double(known.count)
        return days.map { known[$0] ?? average }
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

    /// The last `count` working days strictly before `end` (start of day), oldest first.
    func workingDays(before end: Date, count: Int) -> [Date] {
        var days: [Date] = []
        var day = end
        while days.count < count {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
            if isWorkingDay(day) { days.insert(day, at: 0) }
        }
        return days
    }

    /// GitHub resets quotas at midnight UTC; the local day carrying the same date
    /// is used as the boundary so the period never spills over into another day.
    func localDay(matchingUTCDayOf date: Date) -> Date {
        let components = Self.utcCalendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: date)
    }

    /// Linearly weighted average where the most recent value weighs the most,
    /// yet never more than twice as much as the oldest one.
    func weightedAverage(_ values: [Double]) -> Double {
        let weights = (values.count + 1...values.count * 2).map(Double.init)
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
