import SwiftUI

struct Last7DaysMenu: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Menu("Recent Days (Summary)") {
            if appState.last7Days.isEmpty {
                Text("No history recorded yet")
            } else {
                ForEach(appState.last7Days.reversed()) { day in
                    Text("\(day.label): \(ByteFormat.string(bytes: day.downloadBytes + day.uploadBytes))")
                }
                Divider()
                Button("Open History Matrix...") {
                    WindowManager.shared.showSettings(tab: .history)
                }
            }
        }
    }
}

#Preview {
    Last7DaysMenu().environmentObject(MockAppState())
}
