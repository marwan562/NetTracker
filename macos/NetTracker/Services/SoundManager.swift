import AppKit
import Foundation

/// SoundManager provides clean, single-event native macOS acoustic feedback for NetTracker.
/// It uses light, singular acoustic cues (Tink, Blow) without artificial haptic repetition,
/// preventing the perception of accidental double-clicks.
final class SoundManager {
    static let shared = SoundManager()

    private init() {}

    /// Setting key for sound effects preference
    static let soundEffectsKey = "soundEffectsEnabled"

    var isSoundEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.soundEffectsKey) as? Bool ?? true
    }

    /// Clean, singular subtle tick for selecting chart days or elements
    func playSelect() {
        guard isSoundEnabled else { return }
        NSSound(named: NSSound.Name("Tink"))?.play()
    }

    /// Subtle toggle tick
    func playToggle() {
        guard isSoundEnabled else { return }
        NSSound(named: NSSound.Name("Tink"))?.play()
    }

    /// Distinct sweep sound for resetting statistics
    func playReset() {
        guard isSoundEnabled else { return }
        NSSound(named: NSSound.Name("Blow"))?.play()
    }

    /// Uplifting chime for completed operations
    func playSuccess() {
        guard isSoundEnabled else { return }
        NSSound(named: NSSound.Name("Hero"))?.play()
    }
}
