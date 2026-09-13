import SwiftUI

struct TodaySection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            Text("Today")
                .font(.headline)
            LabeledContent("↓ Download", value: ByteFormat.string(bytes: appState.snapshot.todayDownloadBytes))
            LabeledContent("↑ Upload", value: ByteFormat.string(bytes: appState.snapshot.todayUploadBytes))
            LabeledContent("↓ Down rate", value: ByteFormat.string(bytes: appState.snapshot.currentDownloadRate, rate: true))
            LabeledContent("↑ Up rate", value: ByteFormat.string(bytes: appState.snapshot.currentUploadRate, rate: true))
        }
    }
}

#Preview {
    TodaySection().environmentObject(MockAppState())
}
