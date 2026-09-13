import AppKit
import Foundation

@MainActor
final class SleepMonitor {
    var onSleep: (() -> Void)?
    var onWake: (() -> Void)?
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(didSleep), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func didSleep() { onSleep?() }
    @objc private func didWake() { onWake?() }
}
