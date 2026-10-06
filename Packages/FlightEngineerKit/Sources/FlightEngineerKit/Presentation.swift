import Foundation

public extension Outlook {
    var title: String {
        switch self {
        case .creditsLeft: "Credits left"
        case .reachingQuota: "Reaching quota"
        case .shortage: "Shortage"
        }
    }

    var symbolName: String {
        switch self {
        case .creditsLeft: "arrow.down.right.circle.fill"
        case .reachingQuota: "arrow.right.circle.fill"
        case .shortage: "arrow.up.right.circle.fill"
        }
    }
}

public extension Forecast {
    /// Short explanation of the outlook, e.g. "Runs out Oct 21" or "4,200 left at reset".
    func summary(resetDate: Date) -> String {
        if let depletionDay {
            return "Runs out \(depletionDay.formatted(.dateTime.month(.abbreviated).day()))"
        }
        let balance = Int(projectedBalance.rounded())
        return "\(balance.formatted()) left on \(resetDate.formatted(.dateTime.month(.abbreviated).day()))"
    }
}

public extension Double {
    var credits: String {
        Int(rounded()).formatted()
    }
}
