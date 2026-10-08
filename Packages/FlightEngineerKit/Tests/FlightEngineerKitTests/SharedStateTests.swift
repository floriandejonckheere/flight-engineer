import Foundation
import Testing
@testable import FlightEngineerKit

struct SharedStateTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return calendar
    }()

    private let resetDate = Date(timeIntervalSince1970: 1_793_491_200)

    private func snapshot(day: Int, hour: Int, used: Double) -> UsageSnapshot {
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
        return UsageSnapshot(date: date, used: used, total: 30000, resetDate: resetDate)
    }

    @Test func keepsLastSnapshotOfPastDaysAndAllOfToday() {
        var state = SharedState()
        state.record(snapshot(day: 5, hour: 9, used: 100), calendar: calendar)
        state.record(snapshot(day: 5, hour: 17, used: 200), calendar: calendar)
        state.record(snapshot(day: 6, hour: 9, used: 250), calendar: calendar)
        state.record(snapshot(day: 6, hour: 10, used: 300), calendar: calendar)

        #expect(state.snapshots.map(\.used) == [200, 250, 300])
        #expect(state.latest?.used == 300)
    }

    @Test func dropsSnapshotsBeyondRetention() {
        var state = SharedState()
        state.record(snapshot(day: 1, hour: 9, used: 100), calendar: calendar)
        state.record(snapshot(day: 6, hour: 9, used: 200), calendar: calendar, retentionDays: 3)

        #expect(state.snapshots.map(\.used) == [200])
    }

    @Test func becomesStaleAfterAnHourWithoutSuccess() {
        let lastSuccess = Date(timeIntervalSince1970: 1_790_000_000)
        let state = SharedState(status: .ok, lastSuccess: lastSuccess)

        #expect(!state.isStale(at: lastSuccess.addingTimeInterval(60 * 60)))
        #expect(state.isStale(at: lastSuccess.addingTimeInterval(60 * 60 + 1)))
        #expect(SharedState().isStale(at: lastSuccess))
    }

    @Test func roundTripsThroughDisk() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let state = SharedState(status: .failed("Boom"), lastAttempt: Date(timeIntervalSince1970: 1_790_000_000), plan: "business", snapshots: [snapshot(day: 6, hour: 9, used: 42)])
        try SharedStore.save(state, to: url)

        #expect(SharedStore.load(from: url) == state)
    }
}
