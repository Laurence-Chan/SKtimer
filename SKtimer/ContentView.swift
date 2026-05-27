import Charts
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TimerStore

    @State private var hoursText = ""
    @State private var minutesText = "25"
    @State private var inputError: TimerInputError?
    @State private var knownMeaningfulRecordIDs = Set<UUID>()
    @State private var intakeAnimation: MeaningfulIntakeAnimation?
    @State private var intakeAnimationSettled = false
    @FocusState private var focusedField: TimerInputField?

    var body: some View {
        VStack(alignment: .center, spacing: DesignSystem.Spacing.xxl) {
            RecentDurationsStrip(
                durations: store.recentDurations,
                selectDuration: selectRecentDuration,
                accessibilityLabel: timerAccessibilityLabel
            )

            StartTimerPanel(
                hoursText: $hoursText,
                minutesText: $minutesText,
                inputError: inputError,
                focusedField: $focusedField,
                startTimer: startTimer
            )

            TimerListPanel(
                timers: store.activeTimers,
                pauseOrResume: pauseOrResume,
                restart: restart,
                delete: delete
            )

            DashboardHeader(
                stats: store.meaningfulStats,
                intakeTargetActive: intakeAnimation != nil,
                chartBars: { period in
                    store.meaningfulChartBars(for: period)
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(DesignSystem.Spacing.panel)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlayPreferenceValue(MeaningfulIntakeAnchorPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                meaningfulIntakeOverlay(anchors: anchors, proxy: proxy)
            }
        }
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
        .onAppear {
            knownMeaningfulRecordIDs = Set(store.meaningfulTimeRecords.map(\.id))
        }
        .onChange(of: store.meaningfulTimeRecords) { _, records in
            handleMeaningfulRecordChange(records)
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

    private func selectRecentDuration(duration: Int) {
        let hours = duration / 60
        let minutes = duration % 60

        hoursText = hours == 0 ? "" : "\(hours)"
        minutesText = "\(minutes)"
        inputError = nil
        focusedField = hours > 0 ? .hours : .minutes
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

    @ViewBuilder
    private func meaningfulIntakeOverlay(
        anchors: [MeaningfulIntakeAnchorRole: Anchor<CGRect>],
        proxy: GeometryProxy
    ) -> some View {
        if let intakeAnimation,
           let sourceAnchor = anchors[.timerList],
           let targetAnchor = anchors[.dailyStat] {
            MeaningfulIntakeOverlay(
                animation: intakeAnimation,
                sourceFrame: proxy[sourceAnchor],
                targetFrame: proxy[targetAnchor],
                isSettled: intakeAnimationSettled
            )
            .allowsHitTesting(false)
        }
    }

    private func handleMeaningfulRecordChange(_ records: [MeaningfulTimeRecord]) {
        let newMeaningfulRecords = records
            .filter { $0.wasMeaningful && !knownMeaningfulRecordIDs.contains($0.id) }
            .sorted { $0.answeredAt < $1.answeredAt }

        knownMeaningfulRecordIDs = Set(records.map(\.id))

        guard let record = newMeaningfulRecords.last else {
            return
        }

        startMeaningfulIntakeAnimation(for: record)
    }

    private func startMeaningfulIntakeAnimation(for record: MeaningfulTimeRecord) {
        let animation = MeaningfulIntakeAnimation(durationSeconds: record.durationSeconds)
        intakeAnimation = animation
        intakeAnimationSettled = false

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000)
            guard intakeAnimation?.id == animation.id else {
                return
            }

            withAnimation(.interpolatingSpring(mass: 0.65, stiffness: 170, damping: 18, initialVelocity: 1.8)) {
                intakeAnimationSettled = true
            }

            try? await Task.sleep(nanoseconds: 760_000_000)
            guard intakeAnimation?.id == animation.id else {
                return
            }

            withAnimation(.easeOut(duration: 0.16)) {
                intakeAnimation = nil
                intakeAnimationSettled = false
            }
        }
    }
}

private enum TimerInputField {
    case hours
    case minutes
}

private enum MeaningfulIntakeAnchorRole: Hashable {
    case timerList
    case dailyStat
}

private struct MeaningfulIntakeAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [MeaningfulIntakeAnchorRole: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [MeaningfulIntakeAnchorRole: Anchor<CGRect>],
        nextValue: () -> [MeaningfulIntakeAnchorRole: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct MeaningfulIntakeAnimation: Identifiable, Equatable {
    let id = UUID()
    let durationSeconds: Int
}

private struct DashboardHeader: View {
    let stats: MeaningfulTimeStats
    let intakeTargetActive: Bool
    let chartBars: (MeaningfulStatsPeriod) -> [MeaningfulChartBar]

    @State private var presentedPeriod: MeaningfulStatsPeriod?

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ForEach(MeaningfulStatsPeriod.allCases) { period in
                CompactStatPill(
                    period: period,
                    value: TimerDurationFormatter.compact(seconds: stats.seconds(for: period)),
                    isIntakeTarget: intakeTargetActive && period == .daily
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
    let isIntakeTarget: Bool
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
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.small, style: .continuous)
                    .stroke(Color.accentColor.opacity(isIntakeTarget ? 0.75 : 0), lineWidth: 1.5)
            }
            .scaleEffect(isIntakeTarget ? 1.04 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isIntakeTarget)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(period.buttonAccessibilityIdentifier)
        .anchorPreference(
            key: MeaningfulIntakeAnchorPreferenceKey.self,
            value: .bounds
        ) { anchor in
            period == .daily ? [.dailyStat: anchor] : [:]
        }
    }
}

private struct MeaningfulIntakeOverlay: View {
    let animation: MeaningfulIntakeAnimation
    let sourceFrame: CGRect
    let targetFrame: CGRect
    let isSettled: Bool

    private var sourcePoint: CGPoint {
        CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)
    }

    private var targetPoint: CGPoint {
        CGPoint(x: targetFrame.midX, y: targetFrame.midY)
    }

    var body: some View {
        Text(TimerDurationFormatter.compact(seconds: animation.durationSeconds))
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.accentColor.gradient, in: Capsule(style: .continuous))
            .shadow(color: Color.accentColor.opacity(isSettled ? 0.15 : 0.38), radius: isSettled ? 2 : 14, y: isSettled ? 1 : 7)
            .scaleEffect(
                x: isSettled ? 0.28 : 1,
                y: isSettled ? 0.08 : 1,
                anchor: .center
            )
            .opacity(isSettled ? 0.12 : 1)
            .blur(radius: isSettled ? 0.7 : 0)
            .position(isSettled ? targetPoint : sourcePoint)
            .accessibilityHidden(true)
            .accessibilityIdentifier("meaningfulIntakeAnimation")
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

    private var isFocused: Bool {
        focusedField == focus
    }

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(isFocused ? Color.accentColor : .secondary)
                .frame(width: 76, alignment: .center)

            TextField("0", text: $text)
                .textFieldStyle(.plain)
                .tint(.clear)
                .font(.system(.title2, design: .rounded, weight: .medium).monospacedDigit())
                .multilineTextAlignment(.center)
                .frame(width: 76, height: 38)
                .background(fieldBackground, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.small, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.small, style: .continuous)
                        .stroke(isFocused ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isFocused ? 2 : 1)
                }
                .shadow(color: isFocused ? Color.accentColor.opacity(0.22) : .clear, radius: 6, y: 1)
                .focused($focusedField, equals: focus)
                .accessibilityIdentifier(identifier)
        }
        .animation(.easeOut(duration: 0.12), value: isFocused)
    }

    private var fieldBackground: Color {
        if isFocused {
            return Color.accentColor.opacity(0.08)
        }

        return Color(nsColor: .textBackgroundColor)
    }
}

private struct RecentDurationsStrip: View {
    let durations: [Int]
    let selectDuration: (Int) -> Void
    let accessibilityLabel: (Int) -> String

    var body: some View {
        if !durations.isEmpty {
            HStack(spacing: 10) {
                ForEach(durations, id: \.self) { duration in
                    Button {
                        selectDuration(duration)
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
        .anchorPreference(
            key: MeaningfulIntakeAnchorPreferenceKey.self,
            value: .bounds
        ) { anchor in
            [.timerList: anchor]
        }
    }
}
