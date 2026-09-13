import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case history
    case general
    case about

    var id: String { rawValue }
}

struct SettingsView: View {
    @ObservedObject var windowManager = WindowManager.shared

    var body: some View {
        TabView(selection: $windowManager.selectedTab) {
            UsageHistoryView()
                .tabItem {
                    Label("Usage History", systemImage: "chart.bar.xaxis")
                }
                .tag(SettingsTab.history)

            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 680, height: 530)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var loginItems: LoginItemManager
    @EnvironmentObject var appState: AppState
    @AppStorage(SoundManager.soundEffectsKey) private var soundEffectsEnabled = true
    @State private var errorMessage: String?
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section(header: Text("Startup & Integration").font(.headline)) {
                Toggle("Launch NetTracker at login", isOn: Binding(
                    get: { loginItems.launchAtLogin },
                    set: { value in
                        SoundManager.shared.playToggle()
                        do {
                            try loginItems.setLaunchAtLogin(value)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                ))

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Text("Automatically begins monitoring network activity upon logging into macOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Sound & Haptics").font(.headline)) {
                HStack {
                    Toggle("Play system sound effects", isOn: Binding(
                        get: { soundEffectsEnabled },
                        set: { value in
                            soundEffectsEnabled = value
                            if value { SoundManager.shared.playToggle() }
                        }
                    ))

                    Spacer()

                    Button("Test Sound") {
                        SoundManager.shared.playSelect()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Text("Plays subtle native macOS acoustic cues when selecting days, toggling options, and resetting counters.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Measurement Engine").font(.headline)) {
                LabeledContent("Engine Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(engineStatusColor)
                            .frame(width: 8, height: 8)
                        Text(engineStatusText)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }

                LabeledContent("Network Interface") {
                    Text(networkInterfaceText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Architecture") {
                    Text("Go Measurement Daemon (Unix Domain Socket)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text("Data & Reset").font(.headline)) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset Statistics")
                            .font(.subheadline)
                        Text("Clears session and today's accumulated upload/download usage counters.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Reset Statistics...") {
                        showResetConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding(10)
        .onAppear { loginItems.refresh() }
        .confirmationDialog(
            "Are you sure you want to reset your network usage statistics?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Statistics", role: .destructive) {
                Task {
                    await appState.resetStatistics()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset your current session and today's byte counters to zero. Historical days will remain intact.")
        }
    }

    private var engineStatusColor: Color {
        switch appState.agentConnection {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .red
        }
    }

    private var engineStatusText: String {
        switch appState.agentConnection {
        case .connected: return "Connected (Low-overhead polling)"
        case .connecting: return "Connecting to agent..."
        case .disconnected(let err): return "Disconnected (\(err))"
        }
    }

    private var networkInterfaceText: String {
        switch appState.networkStatus {
        case .connected(let name): return name
        case .disconnected: return "No active interface"
        case .unknown: return "Detecting..."
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Icon with decorative background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text("NetTracker")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version 0.1.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Native, lightweight network usage tracker built for the macOS ecosystem.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            // Feature Highlights
            HStack(spacing: 20) {
                featureBadge(icon: "swift", title: "SwiftUI Front-End", subtitle: "macOS HIG native")
                featureBadge(icon: "bolt.fill", title: "Go Core Engine", subtitle: "Kernel counter sampling")
                featureBadge(icon: "lock.shield.fill", title: "Privacy First", subtitle: "No packet inspection")
            }
            .padding(.top, 10)

            Spacer()

            Divider()

            HStack {
                Text("Created with care for macOS.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                Link(destination: URL(string: "https://github.com/marwan562/netracker")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                        Text("GitHub Repository")
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .padding(20)
    }

    private func featureBadge(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.blue)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(width: 140)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }
}

#Preview {
    SettingsView()
        .environmentObject(MockAppState())
        .environmentObject(LoginItemManager())
}
