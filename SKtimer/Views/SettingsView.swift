import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var preferences: TimerPreferences
    @EnvironmentObject private var notificationScheduler: NotificationScheduler
    @State private var soundImportError: String?
    @State private var previewSound: NSSound?
    private let privacyPolicyURL = URL(string: "https://github.com/Laurence-Chan/SKtimer/blob/main/PRIVACY.md")

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsHeader()

            SettingsSection {
                VStack(alignment: .leading, spacing: 14) {
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
            }

            SettingsSection {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Label("settings.notifications.title", systemImage: "bell.badge")
                            .font(.headline)

                        Spacer()

                        Text(LocalizedStringKey(notificationScheduler.authorizationLabelKey))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("settings.notifications.sound.title")
                                .font(.subheadline.weight(.medium))

                            Spacer()

                            Text(soundStatusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        HStack(spacing: 8) {
                            Button {
                                chooseNotificationSound()
                            } label: {
                                Label("settings.notifications.sound.choose", systemImage: "folder")
                            }
                            .accessibilityIdentifier("chooseNotificationSoundButton")

                            Button {
                                playNotificationSoundPreview()
                            } label: {
                                Label("settings.notifications.sound.preview", systemImage: "play.fill")
                            }
                            .accessibilityIdentifier("previewNotificationSoundButton")

                            Button {
                                preferences.clearNotificationSound()
                                soundImportError = nil
                            } label: {
                                Label("settings.notifications.sound.system", systemImage: "speaker.wave.2")
                            }
                            .disabled(preferences.notificationSoundFileName == nil)
                            .accessibilityIdentifier("useSystemNotificationSoundButton")
                        }

                        if let soundImportError {
                            Text(soundImportError)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("notificationSoundErrorLabel")
                        }
                    }

                    Text("settings.notifications.description")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsSection {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "globe")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("settings.language.title")
                            .font(.headline)

                        Text("settings.language.description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let privacyPolicyURL {
                SettingsSection {
                    Link(destination: privacyPolicyURL) {
                        Label("settings.privacyPolicy", systemImage: "lock.doc")
                    }
                    .accessibilityIdentifier("privacyPolicyLink")
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var soundStatusText: LocalizedStringKey {
        if preferences.notificationSoundFileName == nil {
            return "settings.notifications.sound.systemStatus"
        }

        return LocalizedStringKey(preferences.notificationSoundDisplayName ?? "")
    }

    private func chooseNotificationSound() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = TimerPreferences.supportedNotificationSoundContentTypes
        panel.title = String(localized: "settings.notifications.sound.panelTitle")
        panel.prompt = String(localized: "settings.notifications.sound.panelPrompt")

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try preferences.importNotificationSound(from: url)
            soundImportError = nil
        } catch {
            soundImportError = String(localized: "settings.notifications.sound.importError")
        }
    }

    private func playNotificationSoundPreview() {
        if
            let url = preferences.notificationSoundURL,
            FileManager.default.fileExists(atPath: url.path),
            let sound = NSSound(contentsOf: url, byReference: false)
        {
            previewSound = sound
            sound.play()
            return
        }

        NSSound.beep()
    }
}

private struct SettingsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("settings.title")
                .font(.system(.title2, design: .rounded, weight: .semibold))

            Text("settings.subtitle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .card()
    }
}
