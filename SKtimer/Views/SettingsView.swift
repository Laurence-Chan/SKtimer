import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: TimerPreferences
    @EnvironmentObject private var notificationScheduler: NotificationScheduler

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("settings.title")
                    .font(.title2.weight(.semibold))

                Text("settings.subtitle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Toggle("settings.showMenuBar", isOn: Binding(
                    get: { preferences.showMenuBar },
                    set: { preferences.showMenuBar = $0 }
                ))
                .accessibilityIdentifier("showMenuBarToggle")

                Toggle("settings.showMenuBarCountdown", isOn: Binding(
                    get: { preferences.showMenuBarCountdown },
                    set: { preferences.showMenuBarCountdown = $0 }
                ))
                .disabled(!preferences.showMenuBar)
                .accessibilityIdentifier("showMenuBarCountdownToggle")
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("settings.notifications.title")
                        .font(.headline)

                    Spacer()

                    Text(LocalizedStringKey(notificationScheduler.authorizationLabelKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button {
                        notificationScheduler.requestAuthorizationIfNeeded()
                    } label: {
                        Label("settings.notifications.request", systemImage: "bell.badge")
                    }
                    .accessibilityIdentifier("requestNotificationsButton")

                    Button {
                        notificationScheduler.openSystemNotificationSettings()
                    } label: {
                        Label("settings.notifications.openSystem", systemImage: "gear")
                    }
                    .accessibilityIdentifier("openNotificationSettingsButton")
                }

                Text("settings.notifications.description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("settings.language.title", systemImage: "globe")
                    .font(.headline)

                Text("settings.language.description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}
