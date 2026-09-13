import AppKit
import Foundation

/// SoundManager provides native macOS acoustic feedback for NetTracker interactions.
/// It uses built-in macOS system sounds and respects user preferences.
final class SoundManager {
    static let shared = SoundManager()

    private init() {}

    /// Setting key for sound effects preference
    static let soundEffectsKey = "soundEffectsEnabled"

    var isSoundEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.soundEffectsKey) as? Bool ?? true
    }

    /// Subtle pop sound for selecting dates, switching tabs, or clicking chart bars
    func playSelect() {
        guard isSoundEnabled else { return }
        NSSound(named: NSSound.Name("Pop"))?.play()
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    /// Crisp tink sound for toggling options or setting switches
    func playToggle() {
        guard isSoundEnabled else { return }
        NSSound(named: NSSound.Name("Tink"))?.play()
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    /// Distinct sweep sound for resetting usage counters
    func playReset() {
        guard isSoundEnabled else { return }
        NSSound(named: NSSound.Name("Blow"))?.play()
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    /// Uplifting chime for successful operations
    func playSuccess() {
        guard isSoundEnabled else { return }
        NSSound(named: NSSound.Name("Hero"))?.play()
    }
}
