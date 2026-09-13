import SwiftUI

struct Last7DaysMenu: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Menu("Last 7 Days") {
            if appState.last7Days.isEmpty {
                Text("No history yet")
            } else {
                ForEach(appState.last7Days.reversed()) { day in
                    LabeledContent(day.label, value: ByteFormat.string(bytes: day.downloadBytes + day.uploadBytes))
                }
            }
        }
    }
}

#Preview {
    Last7DaysMenu().environmentObject(MockAppState())
}
