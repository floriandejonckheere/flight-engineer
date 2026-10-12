import Foundation
import Testing
@testable import FlightEngineerKit

struct PresentationTests {
    @Test func formatsUsage() {
        #expect(UsageFormat.percentage.format(12_600, total: 30_000) == "42%")
        #expect(UsageFormat.percentage.format(1, total: 0) == "–")
        #expect(UsageFormat.credits.format(12_600.4, total: 30_000) == 12_600.formatted())
    }
}
