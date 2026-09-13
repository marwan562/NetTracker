import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var onTerminate: (() -> Void)?

    func applicationWillTerminate(_ notification: Notification) {
        onTerminate?()
    }

    @objc func showSettingsWindow(_ sender: Any?) {
        WindowManager.shared.showSettings(tab: .general)
    }
}

@main
struct NetTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var loginItems = LoginItemManager()

    private let sleepMonitor = SleepMonitor()
    private let agentProcess = AgentProcessLauncher()
    @State private var hasBooted = false

    init() {
        agentProcess.launchIfNeeded()
        appDelegate.onTerminate = { [agentProcess] in
            agentProcess.terminate()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenu()
                .environmentObject(appState)
                .environmentObject(networkMonitor)
                .task { boot() }
        } label: {
            MenuBarStatusView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(loginItems)
        }
    }

    @MainActor
    private func boot() {
        guard !hasBooted else { return }
        hasBooted = true
        WindowManager.shared.configure(appState: appState, loginItems: loginItems)
        networkMonitor.onPathChange = {
            Task { @MainActor in
                appState.networkStatus = networkMonitor.status
                await appState.notifyLifecycle(.networkChanged)
            }
        }
        networkMonitor.start()
        sleepMonitor.onSleep = { Task { await appState.notifyLifecycle(.sleep) } }
        sleepMonitor.onWake = { Task { await appState.notifyLifecycle(.wake) } }
        sleepMonitor.start()
        loginItems.refresh()
        appState.networkStatus = networkMonitor.status
        appState.start()
    }
}

private final class AgentProcessLauncher: @unchecked Sendable {
    private var process: Process?

    func launchIfNeeded() {
        let defaultSocket = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NetTracker/agent.sock").path
        let socketPath = ProcessInfo.processInfo.environment["NETTRACKER_SOCKET"] ?? defaultSocket

        if isSocketAlive(path: socketPath) {
            return
        }

        let bundled = Bundle.main.bundlePath + "/Contents/Library/LoginItems/NetTrackerAgent"
        guard FileManager.default.isExecutableFile(atPath: bundled) else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: bundled)
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        self.process = task
    }

    private func isSocketAlive(path: String) -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var timeout = timeval(tv_sec: 0, tv_usec: 200_000)
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_un()
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        addr.sun_family = sa_family_t(AF_UNIX)
        guard path.utf8.count < MemoryLayout.size(ofValue: addr.sun_path) else { return false }

        _ = path.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { dest in
                dest.withMemoryRebound(to: CChar.self, capacity: path.utf8.count + 1) { buf in
                    strcpy(buf, ptr)
                }
            }
        }
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let res = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sptr in
                Darwin.connect(fd, sptr, len)
            }
        }
        return res == 0
    }

    func terminate() {
        if let process, process.isRunning {
            process.terminate()
        }
    }
}
