import Foundation
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published var status: NetworkStatus = .unknown
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "nettracker.pathmonitor")
    var onPathChange: (() -> Void)?
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let name = self.interfaceLabel(for: path)
            let newStatus: NetworkStatus = path.status == .satisfied ? .connected(name) : .disconnected
            Task { @MainActor in
                let changed = self.describe(self.status) != self.describe(newStatus)
                self.status = newStatus
                if changed { self.onPathChange?() }
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        monitor.cancel()
    }

    nonisolated private func interfaceLabel(for path: NWPath) -> String {
        let rawName = path.availableInterfaces.first?.name ?? "Network"
        if path.usesInterfaceType(.wifi) {
            return "Wi-Fi (\(rawName))"
        } else if path.usesInterfaceType(.wiredEthernet) {
            return "Ethernet (\(rawName))"
        } else if path.usesInterfaceType(.cellular) {
            return "Cellular (\(rawName))"
        } else {
            return rawName
        }
    }

    private func describe(_ s: NetworkStatus) -> String {
        switch s {
        case .connected(let n): return "up-" + n
        case .disconnected: return "down"
        case .unknown: return "unknown"
        }
    }
}
