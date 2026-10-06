import Foundation

/// Response of the private `https://github.com/github-copilot/chat/entitlement` endpoint.
/// Only the fields Flight Engineer needs are decoded.
public struct Entitlement: Decodable, Sendable {
    public let plan: String?
    public let quotas: Quotas

    public struct Quotas: Decodable, Sendable {
        public let resetDate: String?
        public let resetDateUtc: String?
        public let overagesEnabled: Bool?
        public let premiumInteractionsQuota: Quota
    }

    public struct Quota: Decodable, Sendable {
        public let total: Double
        public let used: Double
        public let creditsUsed: Double?
        public let unlimited: Bool
        public let percentRemaining: Double?
    }

    public static func decode(from data: Data) throws -> Entitlement {
        try JSONDecoder().decode(Entitlement.self, from: data)
    }

    public var creditsUsed: Double {
        quotas.premiumInteractionsQuota.creditsUsed ?? quotas.premiumInteractionsQuota.used
    }

    public var creditsTotal: Double {
        quotas.premiumInteractionsQuota.total
    }

    public var isUnlimited: Bool {
        quotas.premiumInteractionsQuota.unlimited
    }

    public var resetDate: Date? {
        if let resetDateUtc = quotas.resetDateUtc {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: resetDateUtc) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: resetDateUtc) { return date }
        }
        if let resetDate = quotas.resetDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            return formatter.date(from: resetDate)
        }
        return nil
    }
}
