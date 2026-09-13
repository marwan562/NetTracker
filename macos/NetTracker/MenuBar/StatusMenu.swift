import SwiftUI

struct StatusMenu: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var networkMonitor: NetworkMonitor

    var body: some View {
        Group {
            Text("🌐 Network Usage")
                .font(.headline)
            TodaySection()
            Divider()
            Text("Current Session")
                .font(.headline)
            LabeledContent("↓ Download", value: ByteFormat.string(bytes: appState.snapshot.sessionDownloadBytes))
            LabeledContent("↑ Upload", value: ByteFormat.string(bytes: appState.snapshot.sessionUploadBytes))
            Divider()
            Last7DaysMenu()
            Divider()
            Menu("Network Details") {
                LabeledContent("Status", value: connectionStatusString)
                LabeledContent("Engine", value: agentStatusString)
            }
            Divider()
            Button("Settings...") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            Button("Reset Statistics") {
                Task { await appState.resetStatistics() }
            }
            Divider()
            Button("Quit NetTracker") { NSApplication.shared.terminate(nil) }
        }
    }

    private var connectionStatusString: String {
        switch appState.networkStatus {
        case .connected(let name): return name
        case .disconnected: return "Disconnected"
        case .unknown: return "Checking..."
        }
    }

    private var agentStatusString: String {
        switch appState.agentConnection {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Offline"
        }
    }
}

#Preview {
    StatusMenu()
        .environmentObject(MockAppState())
        .environmentObject(NetworkMonitor())
}
