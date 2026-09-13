import AppKit
import Foundation

@MainActor
class AppState: ObservableObject {
    @Published var snapshot = UsageSnapshot.empty
    @Published var last7Days: [DailyUsage] = []
    @Published var historyDays: [DailyUsage] = []
    @Published var selectedHistoryRange: Int = 7
    @Published var isLoadingHistory: Bool = false
    @Published var networkStatus: NetworkStatus = .unknown
    @Published var agentConnection: AgentConnection = .connecting

    private let client: GoAgentClientProtocol
    private var pollTask: Task<Void, Never>?
    private var isMenuTracking: Bool = false
    private var trackingObservers: [NSObjectProtocol] = []

    init(client: GoAgentClientProtocol = GoAgentClient()) {
        self.client = client
        setupTrackingObservers()
    }

    private func setupTrackingObservers() {
        let start = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isMenuTracking = true
            }
        }

        let end = NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isMenuTracking = false
            }
        }

        trackingObservers = [start, end]
    }

    private var lastHistoryFetch: Date = .distantPast

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { await pollLoop() }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            do {
                let snap = try await client.getSnapshot()
                // Never mutate @Published properties while an NSMenu is tracking.
                // Modifying observed state while a menu is open forces AppKit to rebuild
                // the active menu under the mouse pointer, abruptly dismissing it or causing conflicts.
                if !isMenuTracking {
                    snapshot = snap
                    agentConnection = .connected
                    if historyDays.isEmpty || Date().timeIntervalSince(lastHistoryFetch) >= 30 {
                        await fetchHistory(days: selectedHistoryRange)
                    }
                }
            } catch {
                if !isMenuTracking {
                    agentConnection = .disconnected(error.localizedDescription)
                }
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    func fetchHistory(days: Int? = nil) async {
        let count = days ?? selectedHistoryRange
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        if let items = try? await client.getHistory(days: count) {
            historyDays = items
            if count == 7 {
                last7Days = items
            }
            lastHistoryFetch = Date()
        }
    }

    func setHistoryRange(_ range: Int) async {
        guard selectedHistoryRange != range else { return }
        selectedHistoryRange = range
        await fetchHistory(days: range)
    }

    func refreshHistory() async {
        await fetchHistory(days: selectedHistoryRange)
    }

    func resetStatistics() async {
        SoundManager.shared.playReset()
        try? await client.reset()
        snapshot = .empty
        await refreshHistory()
    }

    func notifyLifecycle(_ event: LifecycleEvent) async {
        try? await client.sendLifecycleEvent(event)
    }
}

final class MockAppState: AppState {
    init() {
        super.init(client: MockGoAgentClient())
        snapshot = UsageSnapshot(sessionUploadBytes: 23_000_000, sessionDownloadBytes: 184_000_000,
                                 todayUploadBytes: 284_000_000, todayDownloadBytes: 1_520_000_000,
                                 currentUploadRate: 48_000, currentDownloadRate: 1_240_000)
        let mockDays: [DailyUsage] = [
            DailyUsage(date: "2026-09-07", label: "Sep 07", uploadBytes: 120_000_000, downloadBytes: 650_000_000, isToday: false),
            DailyUsage(date: "2026-09-08", label: "Sep 08", uploadBytes: 210_000_000, downloadBytes: 1_120_000_000, isToday: false),
            DailyUsage(date: "2026-09-09", label: "Sep 09", uploadBytes: 90_000_000, downloadBytes: 430_000_000, isToday: false),
            DailyUsage(date: "2026-09-10", label: "Sep 10", uploadBytes: 340_000_000, downloadBytes: 2_450_000_000, isToday: false),
            DailyUsage(date: "2026-09-11", label: "Sep 11", uploadBytes: 180_000_000, downloadBytes: 890_000_000, isToday: false),
            DailyUsage(date: "2026-09-12", label: "Sep 12", uploadBytes: 190_000_000, downloadBytes: 982_000_000, isToday: false),
            DailyUsage(date: "2026-09-13", label: "Today", uploadBytes: 284_000_000, downloadBytes: 1_520_000_000, isToday: true),
        ]
        last7Days = mockDays
        historyDays = mockDays
        networkStatus = .connected("Wi-Fi")
        agentConnection = .connected
    }
}
