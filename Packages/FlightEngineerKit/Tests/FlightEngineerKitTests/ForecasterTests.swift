import Foundation
import Testing
@testable import FlightEngineerKit

struct ForecasterTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Brussels")!
        calendar.locale = Locale(identifier: "en_BE")
        return calendar
    }()

    private var forecaster: Forecaster { Forecaster(calendar: calendar) }

    private let septemberReset = Date(timeIntervalSince1970: 1_790_812_800) // 2026-10-01T00:00:00Z
    private let octoberReset = Date(timeIntervalSince1970: 1_793_491_200) // 2026-11-01T00:00:00Z

    private func date(_ day: Int, month: Int = 10, hour: Int = 18) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func day(_ day: Int, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    private func snapshot(_ day: Int, month: Int = 10, hour: Int = 18, used: Double, total: Double = 30000) -> UsageSnapshot {
        UsageSnapshot(date: date(day, month: month, hour: hour), used: used, total: total, resetDate: month == 10 ? octoberReset : septemberReset)
    }

    @Test func returnsNilWithoutSnapshots() {
        #expect(forecaster.forecast(snapshots: [], now: date(6)) == nil)
    }

    @Test func spreadsFirstSnapshotOverElapsedWorkingDays() throws {
        let forecast = try #require(forecaster.forecast(snapshots: [snapshot(6, hour: 10, used: 5499)], now: date(6, hour: 10)))

        // Oct 1, 2, 5 and 6 are the working days elapsed in the period.
        #expect(forecast.dailyRate == 5499.0 / 4)
        #expect(forecast.remainingWorkingDays == 19)
        #expect(forecast.projectedUsage == 30244.5) // 5499 + 18 * 1374.75
        #expect(forecast.outlook == .shortage)
        #expect(forecast.history.map(\.day) == [day(1), day(2), day(5), day(6)])
    }

    @Test func weighsRecentWorkingDaysMore() throws {
        let snapshots = [
            snapshot(1, used: 100),
            snapshot(2, used: 200),
            snapshot(5, used: 600),
            snapshot(6, hour: 10, used: 650),
        ]
        let forecaster = Forecaster(calendar: calendar, window: 3)
        let forecast = try #require(forecaster.forecast(snapshots: snapshots, now: date(6, hour: 10)))

        #expect(forecast.dailyRate == 220) // (100 * 4 + 100 * 5 + 400 * 6) / 15
        #expect(forecast.projectedUsage == 4780) // 650 + 170 + 18 * 220
        #expect(forecast.projectedBalance == 25220)
        #expect(forecast.outlook == .creditsLeft)
        #expect(forecast.depletionDay == nil)
    }

    @Test func fillsUnknownPastDaysWithAverage() throws {
        let snapshots = [
            snapshot(2, used: 200),
            snapshot(5, used: 600),
            snapshot(6, hour: 10, used: 650),
        ]
        let forecaster = Forecaster(calendar: calendar, window: 5)
        let forecast = try #require(forecaster.forecast(snapshots: snapshots, now: date(6, hour: 10)))

        // Sep 29 and 30 are unknown and filled with the average of Oct 1, 2 and 5.
        #expect(forecast.dailyRate == 207.5) // (200 * 6 + 200 * 7 + 100 * 8 + 100 * 9 + 400 * 10) / 40
        #expect(forecast.history.map(\.day) == [day(1), day(2), day(5), day(6)])
    }

    @Test func attributesWeekendUsageToNextWorkingDay() throws {
        let snapshots = [
            snapshot(1, used: 100),
            snapshot(2, used: 200),
            snapshot(3, used: 300),
            snapshot(5, used: 600),
        ]
        let samples = forecaster.dailySamples(from: snapshots)

        #expect(samples == [
            DailyUsage(day: day(1), credits: 100),
            DailyUsage(day: day(2), credits: 100),
            DailyUsage(day: day(5), credits: 400),
        ])
    }

    @Test func excludesWeekendsFromRemainingDays() throws {
        let forecast = try #require(forecaster.forecast(snapshots: [snapshot(3, used: 300)], now: date(3)))

        // Saturday: Oct 5 through Oct 30 leaves 20 working days.
        #expect(forecast.remainingWorkingDays == 20)
        #expect(forecast.dailyRate == 150)
    }

    @Test func detectsReachingQuota() throws {
        let snapshots = [snapshot(6, hour: 10, used: 1000, total: 6000)]
        let forecast = try #require(forecaster.forecast(snapshots: snapshots, now: date(6, hour: 10)))

        // 250 per day: 1000 + 18 * 250 = 5500, which is above 90% of 6000.
        #expect(forecast.projectedUsage == 5500)
        #expect(forecast.outlook == .reachingQuota)
    }

    @Test func predictsDepletionDay() throws {
        let forecast = try #require(forecaster.forecast(snapshots: [snapshot(6, hour: 10, used: 5499, total: 20000)], now: date(6, hour: 10)))

        // 14501 credits left at 1374.75 per day last until the 11th working day.
        #expect(forecast.outlook == .shortage)
        #expect(forecast.depletionDay == day(21))
    }

    @Test func usesPreviousPeriodAtStartOfMonth() throws {
        let snapshots = [
            snapshot(28, month: 9, used: 1000),
            snapshot(29, month: 9, used: 1500),
            snapshot(30, month: 9, used: 2000),
            snapshot(1, hour: 10, used: 100),
        ]
        let forecaster = Forecaster(calendar: calendar, window: 5)
        let forecast = try #require(forecaster.forecast(snapshots: snapshots, now: date(1, hour: 10)))

        // Sep 24, 25, 28 at 50 (spread over 20 working days), Sep 29 and 30 at 500.
        #expect(forecast.dailyRate == 263.75) // (50 * 6 + 50 * 7 + 50 * 8 + 500 * 9 + 500 * 10) / 40
    }

    @Test func ignoresDaysAfterReset() throws {
        let snapshots = [snapshot(30, hour: 10, used: 2000, total: 30000)]
        let forecast = try #require(forecaster.forecast(snapshots: snapshots, now: date(30, hour: 10)))

        #expect(forecast.remainingWorkingDays == 1)
    }
}
