import SwiftUI

struct MenuBarStatusView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
            Text("↓ \(ByteFormat.string(bytes: appState.snapshot.todayDownloadBytes))")
                .monospacedDigit()
        }
    }

    private var iconName: String {
        switch appState.networkStatus {
        case .connected:
            return "wifi"
        case .disconnected:
            return "wifi.slash"
        case .unknown:
            return "network"
        }
    }
}

#Preview {
    MenuBarStatusView().environmentObject(MockAppState())
}
