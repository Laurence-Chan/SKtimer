import AppKit

@MainActor
protocol TimerSoundPlaying: AnyObject {
    func playCompletionSound()
}

@MainActor
final class SystemSoundPlayer: TimerSoundPlaying {
    private weak var preferences: TimerPreferences?
    private var activeSound: NSSound?

    init(preferences: TimerPreferences? = nil) {
        self.preferences = preferences
    }

    func playCompletionSound() {
        if
            let url = preferences?.notificationSoundURL,
            FileManager.default.fileExists(atPath: url.path),
            let sound = NSSound(contentsOf: url, byReference: false)
        {
            activeSound = sound
            sound.play()
            return
        }

        NSSound.beep()
    }
}
