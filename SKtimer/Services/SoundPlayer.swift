import AppKit

@MainActor
protocol TimerSoundPlaying: AnyObject {
    func playCompletionSound()
}

@MainActor
final class SystemSoundPlayer: TimerSoundPlaying {
    func playCompletionSound() {
        NSSound.beep()
    }
}
