import AppKit
import SwiftUI

/// WindowManager handles creating, activating, and focusing the NetTracker Settings and Usage History window.
/// Because NetTracker is a menu-bar accessory application (LSUIElement), this manager ensures windows are
/// properly presented without relying on standard macOS main menu responder chains.
@MainActor
final class WindowManager: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = WindowManager()

    @Published var selectedTab: SettingsTab = .history

    private var settingsWindow: NSWindow?
    private weak var appState: AppState?
    private weak var loginItems: LoginItemManager?

    private override init() {
        super.init()
    }

    /// Store references to dependencies for window injection
    func configure(appState: AppState, loginItems: LoginItemManager) {
        self.appState = appState
        self.loginItems = loginItems
    }

    /// Present the Settings window focused on a specific tab
    func showSettings(tab: SettingsTab = .history) {
        self.selectedTab = tab

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let appState = appState, let loginItems = loginItems else {
            return
        }

        let contentView = SettingsView()
            .environmentObject(appState)
            .environmentObject(loginItems)

        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 530),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NetTracker"
        window.center()
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Display confirmation alert before resetting statistics
    func confirmAndReset() {
        SoundManager.shared.playSelect()
        let alert = NSAlert()
        alert.messageText = "Reset Network Usage Statistics?"
        alert.informativeText = "This will reset your current session and today's byte counters to zero. Historical days will remain intact."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset Statistics")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let appState = appState {
                Task {
                    await appState.resetStatistics()
                }
            }
        }
    }
}
