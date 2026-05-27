import Charts
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TimerStore

    @State private var hoursText = ""
    @State private var minutesText = "25"
    @State private var inputError: TimerInputError?
    @FocusState private var focusedField: TimerInputField?

    var body: some View {
        VStack(alignment: .center, spacing: DesignSystem.Spacing.xxl) {
            DashboardHeader(
                stats: store.meaningfulStats,
                chartBars: { period in
                    store.meaningfulChartBars(for: period)
                }
            )

            StartTimerPanel(
                hoursText: $hoursText,
                minutesText: $minutesText,
                inputError: inputError,
                focusedField: $focusedField,
                startTimer: startTimer
            )

            RecentDurationsStrip(
                durations: store.recentDurations,
                startDuration: startRecentTimer,
                accessibilityLabel: timerAccessibilityLabel
            )

            TimerListPanel(
                timers: store.activeTimers,
                pauseOrResume: pauseOrResume,
                restart: restart,
                delete: delete
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(DesignSystem.Spacing.panel)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Label("toolbar.notifications", systemImage: "bell.badge")
                }
                .help(Text("toolbar.notifications.help"))
                .accessibilityIdentifier("openNotificationSettingsToolbarButton")
            }
        }
        .onChange(of: hoursText) { _, newValue in
            sanitizeHours(newValue)
        }
        .onChange(of: minutesText) { _, newValue in
            sanitizeMinutes(newValue)
        }
        .onSubmit(startTimer)
    }

    private func startTimer() {
        switch TimerInputValidator.durationMinutes(hoursText: hoursText, minutesText: minutesText) {
        case .success(let duration):
            store.startTimer(durationMinutes: duration)
            inputError = nil
            focusedField = .minutes
        case .failure(let error):
            inputError = error
        }
    }

    private func startRecentTimer(duration: Int) {
        store.startTimer(durationMinutes: duration)
        inputError = nil
    }

    private func pauseOrResume(timer: TimerRecord) {
        if timer.state == .paused {
            store.resumeTimer(id: timer.id)
        } else {
            store.pauseTimer(id: timer.id)
        }
    }

    private func restart(timer: TimerRecord) {
        store.restartTimer(id: timer.id)
    }

    private func delete(timer: TimerRecord) {
        store.deleteTimer(id: timer.id)
    }

    private func sanitizeHours(_ newValue: String) {
        let sanitized = TimerInputValidator.sanitizedDigits(newValue, limit: 3)
        if sanitized != newValue {
            hoursText = sanitized
        }
    }

    private func sanitizeMinutes(_ newValue: String) {
        let sanitized = TimerInputValidator.sanitizedDigits(newValue, limit: 2)
        if sanitized != newValue {
            minutesText = sanitized
        }
    }

    private func timerAccessibilityLabel(for duration: Int) -> String {
        String(
            format: String(localized: "timer.recent.accessibility"),
            TimerDurationFormatter.accessibility(minutes: duration)
        )
    }
}

private enum TimerInputField {
    case hours
    case minutes
}

private struct DashboardHeader: View {
    let stats: MeaningfulTimeStats
    let chartBars: (MeaningfulStatsPeriod) -> [MeaningfulChartBar]

    @State private var presentedPeriod: MeaningfulStatsPeriod?

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ForEach(MeaningfulStatsPeriod.allCases) { period in
                CompactStatPill(
                    period: period,
                    value: TimerDurationFormatter.compact(seconds: stats.seconds(for: period))
                ) {
                    presentedPeriod = period
                }
                .popover(isPresented: popoverBinding(for: period), arrowEdge: .bottom) {
                    MeaningfulStatsChartPopover(
                        period: period,
                        totalSeconds: stats.seconds(for: period),
                        bars: chartBars(period)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("meaningfulStatsSection")
    }

    private func popoverBinding(for period: MeaningfulStatsPeriod) -> Binding<Bool> {
        Binding(
            get: {
                presentedPeriod == period
            },
            set: { isPresented in
                if !isPresented, presentedPeriod == period {
                    presentedPeriod = nil
                }
            }
        )
    }
}

private struct CompactStatPill: View {
    let period: MeaningfulStatsPeriod
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(LocalizedStringKey(period.titleKey))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(value)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .accessibilityIdentifier(period.valueAccessibilityIdentifier)
            }
            .frame(minWidth: 72)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .card(fill: .thinMaterial, radius: DesignSystem.Radius.small)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(period.buttonAccessibilityIdentifier)
    }
}

private struct MeaningfulStatsChartPopover: View {
    let period: MeaningfulStatsPeriod
    let totalSeconds: Int
    let bars: [MeaningfulChartBar]

    private var hasMeaningfulTime: Bool {
        bars.contains { $0.seconds > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(period.chartTitleKey))
                    .font(.headline)

                Text(TimerDurationFormatter.compact(seconds: totalSeconds))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }

            if hasMeaningfulTime {
                Chart(bars) { bar in
                    BarMark(
                        x: .value("meaningful.chart.bucket", bar.label),
                        y: .value("meaningful.chart.minutes", Double(bar.seconds) / 60.0)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .accessibilityLabel(bar.label)
                    .accessibilityValue(TimerDurationFormatter.compact(seconds: bar.seconds))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(width: 340, height: 180)
                .accessibilityIdentifier("meaningfulStatsChart_\(period.rawValue)")
            } else {
                Text("meaningful.chart.empty")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 340, height: 180, alignment: .center)
                    .accessibilityIdentifier("meaningfulStatsChartEmpty_\(period.rawValue)")
            }
        }
        .padding(DesignSystem.Spacing.xxxl)
        .accessibilityIdentifier("meaningfulStatsPopover_\(period.rawValue)")
    }
}

private struct StartTimerPanel: View {
    @Binding var hoursText: String
    @Binding var minutesText: String
    let inputError: TimerInputError?
    @FocusState.Binding var focusedField: TimerInputField?
    let startTimer: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            HStack(alignment: .bottom, spacing: 10) {
                DurationField(
                    titleKey: "timer.input.hours",
                    text: $hoursText,
                    identifier: "hoursField",
                    focus: .hours,
                    focusedField: $focusedField
                )

                DurationField(
                    titleKey: "timer.input.minutes",
                    text: $minutesText,
                    identifier: "minutesField",
                    focus: .minutes,
                    focusedField: $focusedField
                )
            }

            Button(action: startTimer) {
                Label("timer.start", systemImage: "play.fill")
                    .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityIdentifier("startTimerButton")

            if let inputError {
                Label(LocalizedStringKey(inputError.localizedKey), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("inputErrorLabel")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(DesignSystem.Spacing.xxxl)
        .card(fill: .regularMaterial)
    }
}

private struct DurationField: View {
    let titleKey: LocalizedStringKey
    @Binding var text: String
    let identifier: String
    let focus: TimerInputField
    @FocusState.Binding var focusedField: TimerInputField?

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .center)

            TextField("0", text: $text)
                .textFieldStyle(.plain)
                .tint(.clear)
                .font(.system(.title2, design: .rounded, weight: .medium).monospacedDigit())
                .multilineTextAlignment(.center)
                .frame(width: 76, height: 38)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.small, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.small, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
                .focused($focusedField, equals: focus)
                .accessibilityIdentifier(identifier)
        }
    }
}

private struct RecentDurationsStrip: View {
    let durations: [Int]
    let startDuration: (Int) -> Void
    let accessibilityLabel: (Int) -> String

    var body: some View {
        if !durations.isEmpty {
            HStack(spacing: 10) {
                ForEach(durations, id: \.self) { duration in
                    Button {
                        startDuration(duration)
                    } label: {
                        Text(TimerDurationFormatter.compact(minutes: duration))
                            .font(.system(.callout, design: .rounded, weight: .medium))
                            .monospacedDigit()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.small, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.small, style: .continuous)
                            .stroke(.quaternary, lineWidth: 1)
                    }
                    .accessibilityLabel(Text(accessibilityLabel(duration)))
                    .accessibilityIdentifier("recentTimerButton_\(duration)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

private struct TimerListPanel: View {
    let timers: [TimerRecord]
    let pauseOrResume: (TimerRecord) -> Void
    let restart: (TimerRecord) -> Void
    let delete: (TimerRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if timers.isEmpty {
                ContentUnavailableView(
                    "timer.empty.title",
                    systemImage: "timer",
                    description: Text("timer.empty.description")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .card(fill: .thinMaterial)
                .accessibilityIdentifier("emptyTimerState")
            } else {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(timers) { timer in
                            TimerRowView(
                                timer: timer,
                                pauseOrResume: {
                                    pauseOrResume(timer)
                                },
                                restart: {
                                    restart(timer)
                                },
                                delete: {
                                    delete(timer)
                                }
                            )
                            .transition(.scale(0.95).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: timers.map(\.id))
                    .padding(.vertical, 2)
                }
                .accessibilityIdentifier("timerList")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
