import AppKit
import Combine
import Foundation
import UserNotifications

@MainActor
protocol TimerNotificationScheduling: AnyObject {
    var canDeliverAudibleNotifications: Bool { get }

    func requestAuthorizationIfNeeded()
    func refreshAuthorizationStatus()
    func scheduleCompletion(for timer: TimerRecord)
    func deliverCompletion(for timer: TimerRecord)
    func cancelNotification(for id: UUID)
}

@MainActor
final class NotificationScheduler: NSObject, ObservableObject, TimerNotificationScheduling, UNUserNotificationCenterDelegate {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center: UNUserNotificationCenter
    private let isTesting: Bool
    private weak var preferences: TimerPreferences?
    private var didRequestAuthorization = false
    private var isRequestingAuthorization = false

    init(
        center: UNUserNotificationCenter = .current(),
        preferences: TimerPreferences? = nil,
        isTesting: Bool = RuntimeEnvironment.isAnyTesting
    ) {
        self.center = center
        self.preferences = preferences
        self.isTesting = isTesting
        super.init()
        center.delegate = self
        refreshAuthorizationStatus()
    }

    var canDeliverAudibleNotifications: Bool {
        Self.canDeliverAudibleNotifications(for: authorizationStatus)
    }

    var authorizationLabelKey: String {
        switch authorizationStatus {
        case .notDetermined:
            "settings.notifications.notDetermined"
        case .denied:
            "settings.notifications.denied"
        case .authorized:
            "settings.notifications.authorized"
        case .provisional:
            "settings.notifications.provisional"
        case .ephemeral:
            "settings.notifications.ephemeral"
        @unknown default:
            "settings.notifications.unknown"
        }
    }

    func requestAuthorizationIfNeeded() {
        guard !isTesting else {
            authorizationStatus = .denied
            return
        }

        guard !isRequestingAuthorization else {
            return
        }

        guard !didRequestAuthorization else {
            refreshAuthorizationStatus()
            return
        }

        didRequestAuthorization = true
        isRequestingAuthorization = true

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                isRequestingAuthorization = false
            }

            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else {
                authorizationStatus = settings.authorizationStatus
                return
            }

            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            refreshAuthorizationStatus()
        }
    }

    func refreshAuthorizationStatus() {
        guard !isTesting else {
            authorizationStatus = .denied
            return
        }

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let settings = await center.notificationSettings()
            authorizationStatus = settings.authorizationStatus
        }
    }

    func scheduleCompletion(for timer: TimerRecord) {
        guard timer.state == .running else {
            return
        }

        let remainingSeconds = timer.remainingSeconds(at: Date())
        guard remainingSeconds > 0 else {
            return
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, remainingSeconds)), repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier(for: timer.id), content: notificationContent(for: timer), trigger: trigger)
        cancelNotification(for: timer.id)
        center.add(request)
    }

    func deliverCompletion(for timer: TimerRecord) {
        let identifier = notificationIdentifier(for: timer.id)
        let request = UNNotificationRequest(identifier: identifier, content: notificationContent(for: timer), trigger: nil)

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let settings = await center.notificationSettings()
            authorizationStatus = settings.authorizationStatus

            guard Self.canDeliverAudibleNotifications(for: settings.authorizationStatus) else {
                return
            }

            async let pendingRequests = center.pendingNotificationRequests()
            async let deliveredNotifications = center.deliveredNotifications()

            let hasPendingRequest = await pendingRequests.contains { $0.identifier == identifier }
            let hasDeliveredNotification = await deliveredNotifications.contains { $0.request.identifier == identifier }

            guard !hasPendingRequest, !hasDeliveredNotification else {
                return
            }

            try? await center.add(request)
        }
    }

    func cancelNotification(for id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(for: id)])
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    private func notificationIdentifier(for id: UUID) -> String {
        "SKtimer.timer.\(id.uuidString)"
    }

    private static func canDeliverAudibleNotifications(for status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional
    }

    private func notificationContent(for timer: TimerRecord) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.timerComplete.title")
        content.body = String(
            format: String(localized: "notification.timerComplete.body"),
            TimerDurationFormatter.compact(minutes: timer.durationMinutes)
        )
        if
            let fileName = preferences?.notificationSoundFileName,
            let url = preferences?.notificationSoundURL,
            FileManager.default.fileExists(atPath: url.path)
        {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(fileName))
        } else {
            content.sound = .default
        }
        content.interruptionLevel = .timeSensitive
        return content
    }
}
