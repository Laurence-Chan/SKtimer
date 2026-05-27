import SwiftUI

struct TimerRowView: View {
    let timer: TimerRecord
    let pauseOrResume: () -> Void
    let restart: () -> Void
    let delete: () -> Void

    @State private var isHovering = false
    @State private var didComplete = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack(alignment: .center, spacing: 12) {
                StateMark(systemImage: stateIcon, color: stateColor)
                    .scaleEffect(didComplete ? 1.15 : 1.0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(TimerDurationFormatter.compact(minutes: timer.durationMinutes))
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .monospacedDigit()

                    Label(LocalizedStringKey(timer.state.localizedKey), systemImage: stateIcon)
                        .font(.caption)
                        .foregroundStyle(stateColor)
                        .labelStyle(.titleAndIcon)
                }

                Spacer(minLength: 12)

                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text(timer.state == .completed ? String(localized: "timer.done") : TimerDurationFormatter.menuBar(seconds: timer.remainingSeconds(at: timeline.date)))
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityIdentifier("timerRemaining_\(timer.id.uuidString)")
                }
            }

            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let remaining = timer.remainingSeconds(at: timeline.date)
                let isUrgent = timer.state == .running && remaining <= 60
                ProgressView(value: timer.progress(at: timeline.date))
                    .tint(Self.progressTint(remaining: remaining, state: timer.state))
                    .scaleEffect(y: isUrgent ? 1.6 : 1.0, anchor: .center)
                    .animation(.easeInOut(duration: 0.5), value: isUrgent)
                    .accessibilityLabel(Text("timer.progress.accessibility"))
            }

            HStack(spacing: 8) {
                Button(action: pauseOrResume) {
                    Label(
                        timer.state == .paused ? "timer.resume" : "timer.pause",
                        systemImage: timer.state == .paused ? "play.fill" : "pause.fill"
                    )
                }
                .disabled(timer.state == .completed)
                .accessibilityIdentifier("pauseResumeButton_\(timer.id.uuidString)")

                if isHovering {
                    Button(action: restart) {
                        Label("timer.restart", systemImage: "arrow.clockwise")
                    }
                    .accessibilityIdentifier("restartButton_\(timer.id.uuidString)")

                    Button(role: .destructive, action: delete) {
                        Label("timer.delete", systemImage: "trash")
                    }
                    .accessibilityIdentifier("deleteButton_\(timer.id.uuidString)")
                }

                Spacer(minLength: 0)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .animation(.easeOut(duration: 0.15), value: isHovering)
        }
        .padding(DesignSystem.Spacing.xl)
        .card(border: stateColor.opacity(timer.state == .completed ? 0.28 : 0.18))
        .animation(.easeInOut(duration: 0.3), value: timer.state)
        .onHover { isHovering = $0 }
        .onChange(of: timer.state) { _, newState in
            if newState == .completed {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    didComplete = true
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timerRow_\(timer.id.uuidString)")
    }

    private var stateIcon: String {
        switch timer.state {
        case .running:
            "play.circle.fill"
        case .paused:
            "pause.circle.fill"
        case .completed:
            "checkmark.circle.fill"
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

    private static func progressTint(remaining: Int, state: TimerState) -> Color {
        if state == .completed { return .green }
        if remaining <= 60 { return .red }
        if remaining <= 300 { return .orange }
        return .accentColor
    }
}

private struct StateMark: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.small, style: .continuous))
    }
}
