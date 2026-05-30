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
            sender.windows.first?.presentOnActiveSpace()
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
        let isUITesting = arguments.contains("--uitesting")
        let completionDelayOverrideForTesting = Self.completionDelayOverride(arguments: arguments)
        let isTesting = RuntimeEnvironment.isAnyTesting
        let testingDefaultsSuiteName = "com.laurencechan.SKtimer.UITesting"
        let defaults = isUITesting
            ? UserDefaults(suiteName: testingDefaultsSuiteName) ?? .standard
            : .standard

        if shouldResetState, isUITesting {
            defaults.removePersistentDomain(forName: testingDefaultsSuiteName)
        }

        let persistence = UserDefaultsTimerPersistence(defaults: defaults)
        let preferences = TimerPreferences(defaults: defaults)
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
                .background {
                    MainWindowOpeningBridge(presenter: meaningfulPromptPresenter)
                }
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

    private static func completionDelayOverride(arguments: [String]) -> TimeInterval? {
        if let argument = arguments.first(where: { $0.hasPrefix("--uitesting-fast-timers=") }),
           let value = TimeInterval(argument.dropFirst("--uitesting-fast-timers=".count)) {
            return max(0.1, value)
        }

        return arguments.contains("--uitesting-fast-timers") ? 2 : nil
    }
}

private struct MainWindowOpeningBridge: NSViewRepresentable {
    @Environment(\.openWindow) private var openWindow
    let presenter: MeaningfulPromptWindowPresenter

    func makeCoordinator() -> Coordinator {
        Coordinator(presenter: presenter)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configure(from: view, context: context)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configure(from: nsView, context: context)
    }

    private func configure(from view: NSView, context: Context) {
        presenter.setMainWindowOpener {
            openWindow(id: "main")
        }

        DispatchQueue.main.async {
            if let window = view.window {
                context.coordinator.attach(to: window)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        private let presenter: MeaningfulPromptWindowPresenter
        private weak var window: NSWindow?

        init(presenter: MeaningfulPromptWindowPresenter) {
            self.presenter = presenter
        }

        func attach(to window: NSWindow) {
            guard self.window !== window else {
                return
            }

            if self.window?.delegate === self {
                self.window?.delegate = nil
            }

            self.window = window
            window.configureForActiveSpacePresentation()
            window.isReleasedWhenClosed = false
            window.delegate = self
            presenter.setMainWindow(window)
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            sender.orderOut(nil)
            return false
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
