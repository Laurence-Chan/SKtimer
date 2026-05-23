import Combine
import Foundation

@MainActor
final class TimerPreferences: ObservableObject {
    static let showMenuBarKey = "SKtimer.Preference.showMenuBar"
    static let showMenuBarCountdownKey = "SKtimer.Preference.showMenuBarCountdown"

    @Published var showMenuBar: Bool {
        didSet {
            defaults.set(showMenuBar, forKey: Self.showMenuBarKey)
        }
    }

    @Published var showMenuBarCountdown: Bool {
        didSet {
            defaults.set(showMenuBarCountdown, forKey: Self.showMenuBarCountdownKey)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Self.showMenuBarKey) == nil {
            self.showMenuBar = true
        } else {
            self.showMenuBar = defaults.bool(forKey: Self.showMenuBarKey)
        }

        if defaults.object(forKey: Self.showMenuBarCountdownKey) == nil {
            self.showMenuBarCountdown = true
        } else {
            self.showMenuBarCountdown = defaults.bool(forKey: Self.showMenuBarCountdownKey)
        }
    }

    func reset() {
        showMenuBar = true
        showMenuBarCountdown = true
    }

    static func resetStoredValues(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Self.showMenuBarKey)
        defaults.removeObject(forKey: Self.showMenuBarCountdownKey)
    }
}
