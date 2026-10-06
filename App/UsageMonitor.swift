import AppKit
import FlightEngineerKit
import Observation
import ServiceManagement
import WidgetKit

@MainActor
@Observable
final class UsageMonitor {
    static let refreshInterval: Duration = .seconds(15 * 60)

    private(set) var state = SharedStore.load()
    private(set) var isRefreshing = false

    private let client = EntitlementClient()
    private var refreshLoop: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?

    var forecast: Forecast? {
        Forecaster().forecast(snapshots: state.snapshots, now: .now)
    }

    var launchesAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            try? newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        }
    }

    func start() {
        guard refreshLoop == nil else { return }

        refreshLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let now = Date.now
        state.lastAttempt = now

        do {
            let entitlement = try await client.fetch(cookies: GitHubSession.cookies())
            guard let resetDate = entitlement.resetDate else { throw EntitlementError.invalidResponse }

            state.record(UsageSnapshot(date: now, used: entitlement.creditsUsed, total: entitlement.creditsTotal, resetDate: resetDate))
            state.plan = entitlement.plan
            state.status = .ok
            state.lastSuccess = now
        } catch EntitlementError.signedOut {
            state.status = .signedOut
        } catch {
            state.status = .failed(error.localizedDescription)
        }

        persist()
    }

    func signOut() async {
        await GitHubSession.signOut()
        state.status = .signedOut
        persist()
    }

    private func persist() {
        do {
            try SharedStore.save(state)
        } catch {
            state.status = .failed("Could not save state: \(error.localizedDescription)")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
