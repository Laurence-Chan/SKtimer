import AppKit
import Combine
import SwiftUI

@MainActor
final class MeaningfulPromptWindowPresenter: NSObject, ObservableObject, NSWindowDelegate {
    private weak var store: TimerStore?
    private var activePromptID: UUID?
    private var window: NSWindow?
    private var mainWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var openMainWindow: (() -> Void)?

    func setMainWindow(_ mainWindow: NSWindow) {
        self.mainWindow = mainWindow
        mainWindow.isReleasedWhenClosed = false
    }

    func setMainWindowOpener(_ openMainWindow: @escaping () -> Void) {
        self.openMainWindow = openMainWindow
    }

    func bind(to store: TimerStore) {
        guard self.store !== store else {
            presentNextPromptIfNeeded()
            return
        }

        self.store = store
        cancellables.removeAll()

        store.$pendingMeaningfulPrompts
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.presentNextPromptIfNeeded(activating: true)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.presentNextPromptIfNeeded(activating: false)
                }
            }
            .store(in: &cancellables)

        presentNextPromptIfNeeded(activating: true)
    }

    func presentNextPromptIfNeeded(activating: Bool = true) {
        guard !RuntimeEnvironment.isUnitTesting, let store else {
            return
        }

        guard let prompt = store.nextMeaningfulPrompt else {
            closeWindow()
            return
        }

        if activePromptID == prompt.id, let window {
            if activating {
                showMainTimerWindow()
                window.presentOnActiveSpace(includeFullScreenAuxiliary: true)
            }
            return
        }

        closeWindow()
        activePromptID = prompt.id

        let hostingView = NSHostingView(rootView: MeaningfulPromptView(prompt: prompt) { [weak self] wasMeaningful in
            self?.answer(promptID: prompt.id, wasMeaningful: wasMeaningful)
        })

        let promptWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        promptWindow.title = String(localized: "meaningful.prompt.windowTitle")
        promptWindow.contentView = hostingView
        promptWindow.delegate = self
        promptWindow.isReleasedWhenClosed = false
        promptWindow.level = .floating
        promptWindow.configureForActiveSpacePresentation(includeFullScreenAuxiliary: true)
        promptWindow.center()

        window = promptWindow
        if activating {
            showMainTimerWindow()
        }
        promptWindow.presentOnActiveSpace(includeFullScreenAuxiliary: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow, closingWindow === window else {
            return
        }

        window = nil
        activePromptID = nil

        Task { @MainActor [weak self] in
            self?.presentNextPromptIfNeeded(activating: false)
        }
    }

    private func answer(promptID: UUID, wasMeaningful: Bool) {
        guard activePromptID == promptID else {
            return
        }

        closeWindow()
        store?.answerMeaningfulPrompt(id: promptID, wasMeaningful: wasMeaningful)
        presentNextPromptIfNeeded()
    }

    private func closeWindow() {
        window?.delegate = nil
        window?.close()
        window = nil
        activePromptID = nil
    }

    private func showMainTimerWindow() {
        if revealExistingMainTimerWindow() {
            return
        }

        openMainWindow?()

        DispatchQueue.main.async { [weak self] in
            self?.revealExistingMainTimerWindow()
        }
    }

    @discardableResult
    private func revealExistingMainTimerWindow() -> Bool {
        guard let mainWindow = mainWindow ?? NSApp.windows.first(where: { candidate in
            candidate !== window &&
                candidate.title == String(localized: "app.name") &&
                !candidate.isMiniaturized
        }) ?? NSApp.windows.first(where: { candidate in
            candidate !== window &&
                candidate.title == String(localized: "app.name")
        }) else {
            return false
        }

        mainWindow.presentOnActiveSpace()
        return true
    }
}
