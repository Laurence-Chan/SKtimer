import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !RuntimeEnvironment.isUnitTesting else {
            return
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
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

        let scheduler = NotificationScheduler(isTesting: isTesting)
        let store = TimerStore(
            persistence: persistence,
            notificationScheduler: scheduler,
            soundPlayer: SystemSoundPlayer(),
            completionDelayOverrideForTesting: completionDelayOverrideForTesting
        )

        _preferences = StateObject(wrappedValue: TimerPreferences())
        _notificationScheduler = StateObject(wrappedValue: scheduler)
        _meaningfulPromptPresenter = StateObject(wrappedValue: MeaningfulPromptWindowPresenter())
        _store = StateObject(wrappedValue: store)
        isUnitTesting = RuntimeEnvironment.isUnitTesting
    }

    var body: some Scene {
        WindowGroup("SKtimer", id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(preferences)
                .environmentObject(notificationScheduler)
                .frame(minWidth: 680, minHeight: 520)
                .onAppear {
                    guard !isUnitTesting else {
                        return
                    }

                    meaningfulPromptPresenter.bind(to: store)
                    notificationScheduler.requestAuthorizationIfNeeded()
                    store.startClock()
                }
        }
        .defaultSize(width: 720, height: 560)
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

        MenuBarExtra(isInserted: Binding(
            get: { preferences.showMenuBar },
            set: { preferences.showMenuBar = $0 }
        )) {
            MenuBarTimerView()
                .environmentObject(store)
                .environmentObject(preferences)
        } label: {
            Label {
                Text(preferences.showMenuBarCountdown ? store.menuBarTitle : String(localized: "app.name"))
                    .monospacedDigit()
            } icon: {
                Image(systemName: "timer")
            }
            .accessibilityLabel(Text("menuBar.accessibility.label"))
        }
        .menuBarExtraStyle(.menu)
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
