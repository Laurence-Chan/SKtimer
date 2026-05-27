import AppKit
import SwiftUI

struct MenuBarTimerView: View {
    @EnvironmentObject private var store: TimerStore
    @EnvironmentObject private var preferences: TimerPreferences
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let nextTimer = store.nextRunningTimer {
                VStack(alignment: .leading, spacing: 4) {
                    Label("timer.next", systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        Text(TimerDurationFormatter.menuBar(seconds: nextTimer.remainingSeconds(at: timeline.date)))
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                    }

                    Text(TimerDurationFormatter.compact(minutes: nextTimer.durationMinutes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Divider()
            } else {
                Label("menuBar.noRunningTimer", systemImage: "timer")
                    .foregroundStyle(.secondary)

                Divider()
            }

            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("menuBar.open", systemImage: "macwindow")
            }

            if !store.recentDurations.isEmpty {
                Divider()

                Text("timer.recent.title")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(store.recentDurations, id: \.self) { duration in
                    Button(TimerDurationFormatter.compact(minutes: duration)) {
                        store.startTimer(durationMinutes: duration)
                    }
                }
            }

            Divider()

            Toggle("settings.showMenuBarCountdown", isOn: Binding(
                get: { preferences.showMenuBarCountdown },
                set: { preferences.showMenuBarCountdown = $0 }
            ))

            SettingsLink {
                Label("menuBar.settings", systemImage: "gear")
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("menuBar.quit", systemImage: "power")
            }
        }
        .padding(8)
    }
}
