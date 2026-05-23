import SwiftUI

struct TimerRowView: View {
    let timer: TimerRecord
    let now: Date
    let pauseOrResume: () -> Void
    let restart: () -> Void
    let delete: () -> Void

    private var remainingSeconds: Int {
        timer.remainingSeconds(at: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(TimerDurationFormatter.compact(minutes: timer.durationMinutes))
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .monospacedDigit()

                    Label(LocalizedStringKey(timer.state.localizedKey), systemImage: stateIcon)
                        .font(.caption)
                        .foregroundStyle(stateColor)
                }

                Spacer()

                Text(timer.state == .completed ? String(localized: "timer.done") : TimerDurationFormatter.menuBar(seconds: remainingSeconds))
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .accessibilityIdentifier("timerRemaining_\(timer.id.uuidString)")
            }

            ProgressView(value: timer.progress(at: now))
                .tint(stateColor)
                .accessibilityLabel(Text("timer.progress.accessibility"))

            HStack(spacing: 8) {
                Button(action: pauseOrResume) {
                    Label(
                        timer.state == .paused ? "timer.resume" : "timer.pause",
                        systemImage: timer.state == .paused ? "play.fill" : "pause.fill"
                    )
                }
                .disabled(timer.state == .completed)
                .accessibilityIdentifier("pauseResumeButton_\(timer.id.uuidString)")

                Button(action: restart) {
                    Label("timer.restart", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("restartButton_\(timer.id.uuidString)")

                Button(role: .destructive, action: delete) {
                    Label("timer.delete", systemImage: "trash")
                }
                .accessibilityIdentifier("deleteButton_\(timer.id.uuidString)")

                Spacer()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timerRow_\(timer.id.uuidString)")
    }

    private var stateIcon: String {
        switch timer.state {
        case .running:
            "play.circle"
        case .paused:
            "pause.circle"
        case .completed:
            "checkmark.circle"
        }
    }

    private var stateColor: Color {
        switch timer.state {
        case .running:
            .accentColor
        case .paused:
            .orange
        case .completed:
            .green
        }
    }
}
