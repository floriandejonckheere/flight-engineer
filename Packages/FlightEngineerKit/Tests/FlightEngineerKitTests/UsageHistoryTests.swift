import Foundation
import Testing
@testable import FlightEngineerKit

struct UsageHistoryTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Brussels")!
        calendar.firstWeekday = 2
        return calendar
    }()

    private func day(_ day: Int, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    private var daily: [DailyUsage] {
        [
            DailyUsage(day: day(30, month: 9), credits: 10, isWorkingDay: true),
            DailyUsage(day: day(2), credits: 20, isWorkingDay: true),
            DailyUsage(day: day(4), credits: 30, isWorkingDay: false, isEstimated: true),
            DailyUsage(day: day(5), credits: 40, isWorkingDay: true),
        ]
    }

    @Test func keepsDailyUsage() {
        let usage = daily.grouped(by: .day, calendar: calendar)

        #expect(usage.map(\.credits) == [10, 20, 30, 40])
        #expect(usage.map(\.isWorkingDay) == [true, true, false, true])
        #expect(usage.map(\.isEstimated) == [false, false, true, false])
    }

    @Test func sumsUsagePerWeek() {
        #expect(daily.grouped(by: .week, calendar: calendar) == [
            PeriodUsage(start: day(28, month: 9), credits: 60, isEstimated: true),
            PeriodUsage(start: day(5), credits: 40),
        ])
    }

    @Test func sumsUsagePerMonth() {
        #expect(daily.grouped(by: .month, calendar: calendar) == [
            PeriodUsage(start: day(1, month: 9), credits: 10),
            PeriodUsage(start: day(1), credits: 90, isEstimated: true),
        ])
    }
}
