import Foundation

/// State shared between the menu bar app (writer) and the widget (reader).
public struct SharedState: Codable, Equatable, Sendable {
    public enum Status: Codable, Equatable, Sendable {
        case ok
        case signedOut
        case failed(String)
    }

    public var status: Status
    public var lastAttempt: Date?
    public var lastSuccess: Date?
    public var plan: String?
    public var snapshots: [UsageSnapshot]

    public init(status: Status = .signedOut, lastAttempt: Date? = nil, lastSuccess: Date? = nil, plan: String? = nil, snapshots: [UsageSnapshot] = []) {
        self.status = status
        self.lastAttempt = lastAttempt
        self.lastSuccess = lastSuccess
        self.plan = plan
        self.snapshots = snapshots
    }

    public var latest: UsageSnapshot? {
        snapshots.max { $0.date < $1.date }
    }

    /// Whether the usage has not been fetched successfully within `interval`,
    /// e.g. because the app is not running or fetching keeps failing.
    public func isStale(at now: Date, interval: TimeInterval = 60 * 60) -> Bool {
        guard let lastSuccess else { return true }
        return now.timeIntervalSince(lastSuccess) > interval
    }

    /// Appends a snapshot, keeping only the last snapshot of each past day and
    /// dropping snapshots older than `retentionDays`.
    public mutating func record(_ snapshot: UsageSnapshot, calendar: Calendar = .current, retentionDays: Int = 62) {
        let today = calendar.startOfDay(for: snapshot.date)
        let cutoff = calendar.date(byAdding: .day, value: -retentionDays, to: today)!

        var lastPerDay: [Date: UsageSnapshot] = [:]
        var todaySnapshots: [UsageSnapshot] = []
        for existing in snapshots + [snapshot] {
            let day = calendar.startOfDay(for: existing.date)
            if day < cutoff { continue }
            if day >= today {
                todaySnapshots.append(existing)
            } else if existing.date >= (lastPerDay[day]?.date ?? .distantPast) {
                lastPerDay[day] = existing
            }
        }

        snapshots = (Array(lastPerDay.values) + todaySnapshots).sorted { $0.date < $1.date }
    }
}

public enum SharedStore {
    /// `~/Library/Application Support/FlightEngineer`, resolved outside of any
    /// sandbox container so the app and the sandboxed widget see the same file.
    public static var directory: URL {
        let home = getpwuid(getuid()).flatMap { String(validatingCString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home)
            .appendingPathComponent("Library/Application Support/FlightEngineer", isDirectory: true)
    }

    public static var fileURL: URL {
        directory.appendingPathComponent("state.json")
    }

    public static func load(from url: URL = fileURL) -> SharedState {
        guard let data = try? Data(contentsOf: url) else { return SharedState() }
        return (try? decoder.decode(SharedState.self, from: data)) ?? SharedState()
    }

    public static func save(_ state: SharedState, to url: URL = fileURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(state).write(to: url, options: .atomic)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
