import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 400, height: 220)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var loginItems: LoginItemManager
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { loginItems.launchAtLogin },
                set: { value in
                    do { try loginItems.setLaunchAtLogin(value) }
                    catch { errorMessage = error.localizedDescription }
                }
            ))
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.caption) }
            Text("Usage is tracked locally. Cloud sync is opt-in and off by default.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear { loginItems.refresh() }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.circle.fill")
                .font(.system(size: 48))
            Text("NetTracker")
                .font(.title)
            Text("Lightweight menu-bar network usage tracker.")
                .foregroundStyle(.secondary)
            Text("System network usage. Local-first, no packet inspection.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    SettingsView().environmentObject(LoginItemManager())
}
