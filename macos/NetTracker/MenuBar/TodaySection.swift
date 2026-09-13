import SwiftUI

struct TodaySection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            Text("Today")
                .font(.headline)
            Text("↓ Download: \(ByteFormat.string(bytes: appState.snapshot.todayDownloadBytes))")
            Text("↑ Upload: \(ByteFormat.string(bytes: appState.snapshot.todayUploadBytes))")
            Text("↓ Speed: \(ByteFormat.string(bytes: appState.snapshot.currentDownloadRate, rate: true))")
            Text("↑ Speed: \(ByteFormat.string(bytes: appState.snapshot.currentUploadRate, rate: true))")
        }
    }
}

#Preview {
    TodaySection().environmentObject(MockAppState())
}
