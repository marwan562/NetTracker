import SwiftUI

struct StatusMenu: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var networkMonitor: NetworkMonitor

    var body: some View {
        Group {
            Text("NetTracker")
                .font(.headline)

            Button("Open Usage History...") {
                SoundManager.shared.playSelect()
                WindowManager.shared.showSettings(tab: .history)
            }

            Divider()

            TodaySection()

            Divider()

            Text("Current Session")
                .font(.headline)
            Text("↓ Download: \(ByteFormat.string(bytes: appState.snapshot.sessionDownloadBytes))")
            Text("↑ Upload: \(ByteFormat.string(bytes: appState.snapshot.sessionUploadBytes))")

            Divider()

            Last7DaysMenu()

            Divider()

            Menu("Network Details") {
                Text("Status: \(connectionStatusString)")
                Text("Engine: \(agentStatusString)")
            }

            Divider()

            Button("Settings...") {
                SoundManager.shared.playSelect()
                WindowManager.shared.showSettings(tab: .general)
            }

            Button("Reset Statistics...") {
                WindowManager.shared.confirmAndReset()
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
