import AppKit
import Combine
import Foundation

@MainActor
final class StatusBarController: NSObject, ObservableObject {
    private weak var store: TimerStore?
    private weak var preferences: TimerPreferences?

    private var statusItem: NSStatusItem?
    private var countdownTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var didBind = false
    private var lastButtonTitle: String?
    private var lastButtonShowsIcon: Bool?

    private lazy var iconImage: NSImage? = {
        let image = NSImage(
            systemSymbolName: "timer",
            accessibilityDescription: String(localized: "menuBar.accessibility.label")
        )
        image?.isTemplate = true
        return image
    }()

    func bind(store: TimerStore, preferences: TimerPreferences) {
        guard !didBind else {
            return
        }

        didBind = true
        self.store = store
        self.preferences = preferences

        store.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.refreshAll()
                }
            }
            .store(in: &cancellables)

        preferences.$showMenuBar
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.refreshAll()
                }
            }
            .store(in: &cancellables)

        preferences.$showMenuBarCountdown
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.refreshAll()
                }
            }
            .store(in: &cancellables)

        refreshAll()
    }

    deinit {
        countdownTimer?.invalidate()
    }

    private func refreshAll() {
        updateVisibility()
        updateTitle()
        rebuildMenu()
        updateCountdownTimer()
    }

    private func updateVisibility() {
        guard preferences?.showMenuBar == true else {
            removeStatusItem()
            return
        }

        guard statusItem == nil else {
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = iconImage
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = String(localized: "menuBar.accessibility.label")
        statusItem = item
        lastButtonTitle = nil
        lastButtonShowsIcon = nil
    }

    private func removeStatusItem() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        lastButtonTitle = nil
        lastButtonShowsIcon = nil

        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }

        statusItem = nil
    }

    private func updateTitle() {
        guard
            let button = statusItem?.button,
            let store
        else {
            return
        }

        let isRunningTimerVisible = store.nextRunningTimer != nil && preferences?.showMenuBarCountdown == true
        let title = isRunningTimerVisible ? store.menuBarTitle(at: Date()) : ""
        let showsIcon = !isRunningTimerVisible

        guard title != lastButtonTitle || showsIcon != lastButtonShowsIcon else {
            return
        }

        button.title = title
        button.image = showsIcon ? iconImage : nil
        button.imagePosition = showsIcon ? .imageOnly : .noImage
        lastButtonTitle = title
        lastButtonShowsIcon = showsIcon
    }

    private func updateCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        guard
            preferences?.showMenuBar == true,
            store?.nextRunningTimer != nil
        else {
            return
        }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateTitle()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    private func rebuildMenu() {
        guard
            let statusItem,
            let store,
            let preferences
        else {
            return
        }

        let menu = NSMenu()

        if let nextTimer = store.nextRunningTimer {
            menu.addItem(disabledItem(title: String(localized: "timer.next")))
            menu.addItem(countdownItem(for: nextTimer))
            menu.addItem(disabledItem(title: TimerDurationFormatter.compact(minutes: nextTimer.durationMinutes)))
            menu.addItem(.separator())
        } else {
            menu.addItem(disabledItem(title: String(localized: "menuBar.noRunningTimer")))
            menu.addItem(.separator())
        }

        menu.addItem(targetedItem(
            title: String(localized: "menuBar.open"),
            action: #selector(openMainWindow)
        ))

        if !store.recentDurations.isEmpty {
            menu.addItem(.separator())
            menu.addItem(disabledItem(title: String(localized: "timer.recent.title")))

            for duration in store.recentDurations {
                let item = targetedItem(
                    title: TimerDurationFormatter.compact(minutes: duration),
                    action: #selector(startRecentTimer(_:))
                )
                item.representedObject = duration
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let countdownItem = targetedItem(
            title: String(localized: "settings.showMenuBarCountdown"),
            action: #selector(toggleCountdown)
        )
        countdownItem.state = preferences.showMenuBarCountdown ? .on : .off
        menu.addItem(countdownItem)

        menu.addItem(targetedItem(
            title: String(localized: "menuBar.settings"),
            action: #selector(openSettings)
        ))

        menu.addItem(.separator())
        menu.addItem(targetedItem(
            title: String(localized: "menuBar.quit"),
            action: #selector(quit)
        ))

        statusItem.menu = menu
    }

    private func targetedItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func disabledItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func countdownItem(for timer: TimerRecord) -> NSMenuItem {
        let title = TimerDurationFormatter.menuBar(seconds: timer.remainingSeconds(at: Date()))
        let item = disabledItem(title: title)
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize + 2, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )
        return item
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: { $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func startRecentTimer(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? Int else {
            return
        }

        store?.startTimer(durationMinutes: duration)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleCountdown() {
        preferences?.showMenuBarCountdown.toggle()
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: self)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
