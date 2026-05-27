import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var bootstrap: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !RuntimeEnvironment.isUnitTesting else {
            return
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Self.bootstrap?()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first?.makeKeyAndOrderFront(nil)
        }

        return true
    }
}

@main
struct SKtimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var preferences: TimerPreferences
    @StateObject private var notificationScheduler: NotificationScheduler
    @StateObject private var meaningfulPromptPresenter: MeaningfulPromptWindowPresenter
    @StateObject private var statusBarController: StatusBarController
    @StateObject private var store: TimerStore
    private let isUnitTesting: Bool

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let shouldResetState = arguments.contains("--reset-state")
        let completionDelayOverrideForTesting: TimeInterval? = arguments.contains("--uitesting-fast-timers") ? 2 : nil
        let isTesting = RuntimeEnvironment.isAnyTesting

        let persistence = UserDefaultsTimerPersistence()

        if shouldResetState {
            persistence.reset()
            TimerPreferences.resetStoredValues()
        }

        let preferences = TimerPreferences()
        let scheduler = NotificationScheduler(preferences: preferences, isTesting: isTesting)
        let presenter = MeaningfulPromptWindowPresenter()
        let statusController = StatusBarController()
        let store = TimerStore(
            persistence: persistence,
            notificationScheduler: scheduler,
            soundPlayer: SystemSoundPlayer(preferences: preferences),
            completionDelayOverrideForTesting: completionDelayOverrideForTesting
        )

        _preferences = StateObject(wrappedValue: preferences)
        _notificationScheduler = StateObject(wrappedValue: scheduler)
        _meaningfulPromptPresenter = StateObject(wrappedValue: presenter)
        _statusBarController = StateObject(wrappedValue: statusController)
        _store = StateObject(wrappedValue: store)
        isUnitTesting = RuntimeEnvironment.isUnitTesting

        AppDelegate.bootstrap = {
            presenter.bind(to: store)
            statusController.bind(store: store, preferences: preferences)
            scheduler.requestAuthorizationIfNeeded()
            store.startClock()
        }
    }

    var body: some Scene {
        WindowGroup("SKtimer", id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(preferences)
                .environmentObject(notificationScheduler)
                .frame(minWidth: 600, minHeight: 480)
        }
        .defaultSize(width: 640, height: 520)
        .commands {
            SKtimerCommands()
        }

        Settings {
            SettingsView()
                .environmentObject(preferences)
                .environmentObject(notificationScheduler)
                .frame(width: 420)
                .padding(24)
        }
    }
}

struct SKtimerCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("command.showMainWindow") {
                openWindow(id: "main")
            }
            .keyboardShortcut("0", modifiers: [.command])
        }
    }
}
