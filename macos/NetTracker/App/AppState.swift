import Foundation

@MainActor
class AppState: ObservableObject {
    @Published var snapshot = UsageSnapshot.empty
    @Published var last7Days: [DailyUsage] = []
    @Published var networkStatus: NetworkStatus = .unknown
    @Published var agentConnection: AgentConnection = .connecting

    private let client: GoAgentClientProtocol
    private var pollTask: Task<Void, Never>?

    init(client: GoAgentClientProtocol = GoAgentClient()) {
        self.client = client
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
                snapshot = snap
                agentConnection = .connected
                if last7Days.isEmpty || Date().timeIntervalSince(lastHistoryFetch) >= 60 {
                    if let days = try? await client.getHistory(days: 7) {
                        last7Days = days
                        lastHistoryFetch = Date()
                    }
                }
            } catch {
                agentConnection = .disconnected(error.localizedDescription)
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    func refreshHistory() async {
        if let days = try? await client.getHistory(days: 7) {
            last7Days = days
            lastHistoryFetch = Date()
        }
    }

    func resetStatistics() async {
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
        last7Days = [
            DailyUsage(date: "2026-09-13", label: "Today", uploadBytes: 284_000_000, downloadBytes: 1_520_000_000, isToday: true),
            DailyUsage(date: "2026-09-12", label: "Sep 12", uploadBytes: 190_000_000, downloadBytes: 982_000_000, isToday: false),
        ]
        networkStatus = .connected("Wi-Fi")
        agentConnection = .connected
    }
}
