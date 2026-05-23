import AppKit
import SwiftUI

struct MenuBarTimerView: View {
    @EnvironmentObject private var store: TimerStore
    @EnvironmentObject private var preferences: TimerPreferences
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack {
            if let nextTimer = store.nextRunningTimer {
                Text(TimerDurationFormatter.menuBar(seconds: nextTimer.remainingSeconds(at: store.now)))
                    .font(.headline)
                    .monospacedDigit()

                Text(TimerDurationFormatter.compact(minutes: nextTimer.durationMinutes))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()
            } else {
                Text("menuBar.noRunningTimer")
                    .foregroundStyle(.secondary)

                Divider()
            }

            Button("menuBar.open") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            if !store.recentDurations.isEmpty {
                Divider()

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
                Text("menuBar.settings")
            }

            Button("menuBar.quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .onAppear {
            if !RuntimeEnvironment.isUnitTesting {
                store.startClock()
            }
        }
    }
}
