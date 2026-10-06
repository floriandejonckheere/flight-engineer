import Foundation
import Testing
@testable import FlightEngineerKit

struct EntitlementTests {
    private func fixture() throws -> Entitlement {
        let url = try #require(Bundle.module.url(forResource: "entitlement", withExtension: "json", subdirectory: "Fixtures"))
        return try Entitlement.decode(from: Data(contentsOf: url))
    }

    @Test func decodesCredits() throws {
        let entitlement = try fixture()

        #expect(entitlement.plan == "business")
        #expect(entitlement.creditsUsed == 5499)
        #expect(entitlement.creditsTotal == 30000)
        #expect(entitlement.isUnlimited == false)
    }

    @Test func decodesResetDate() throws {
        let entitlement = try fixture()

        #expect(entitlement.resetDate == Date(timeIntervalSince1970: 1_793_491_200))
    }

    @Test func fallsBackToUsedWithoutCreditsUsed() throws {
        let json = """
        {"quotas": {"resetDate": "2026-11-01", "premiumInteractionsQuota": {"total": 300, "used": 42.5, "unlimited": false}}}
        """
        let entitlement = try Entitlement.decode(from: Data(json.utf8))

        #expect(entitlement.creditsUsed == 42.5)
        #expect(entitlement.resetDate == Date(timeIntervalSince1970: 1_793_491_200))
    }
}
