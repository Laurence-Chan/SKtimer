import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TimerStore
    @EnvironmentObject private var notificationScheduler: NotificationScheduler

    @State private var hoursText = ""
    @State private var minutesText = "25"
    @State private var inputError: TimerInputError?
    @FocusState private var focusedField: TimerInputField?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            meaningfulStatsSection

            inputSection

            recentDurationsSection

            Divider()

            timerList
        }
        .padding(24)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    notificationScheduler.requestAuthorizationIfNeeded()
                } label: {
                    Label("toolbar.notifications", systemImage: "bell.badge")
                }
                .help(Text("toolbar.notifications.help"))
            }
        }
        .onChange(of: hoursText) { _, newValue in
            let sanitized = TimerInputValidator.sanitizedDigits(newValue, limit: 3)
            if sanitized != newValue {
                hoursText = sanitized
            }
        }
        .onChange(of: minutesText) { _, newValue in
            let sanitized = TimerInputValidator.sanitizedDigits(newValue, limit: 2)
            if sanitized != newValue {
                minutesText = sanitized
            }
        }
        .onSubmit(startTimer)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("app.name")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))

                Text("app.tagline")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let nextTimer = store.nextRunningTimer {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("timer.next")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(TimerDurationFormatter.menuBar(seconds: nextTimer.remainingSeconds(at: store.now)))
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .accessibilityIdentifier("nextTimerLabel")
                }
            }
        }
    }

    private var meaningfulStatsSection: some View {
        let stats = store.meaningfulStats

        return HStack(spacing: 10) {
            MeaningfulStatCard(
                titleKey: "meaningful.stats.today",
                value: TimerDurationFormatter.compact(seconds: stats.todaySeconds),
                identifier: "meaningfulStatsTodayValue"
            )

            MeaningfulStatCard(
                titleKey: "meaningful.stats.week",
                value: TimerDurationFormatter.compact(seconds: stats.weekSeconds),
                identifier: "meaningfulStatsWeekValue"
            )

            MeaningfulStatCard(
                titleKey: "meaningful.stats.month",
                value: TimerDurationFormatter.compact(seconds: stats.monthSeconds),
                identifier: "meaningfulStatsMonthValue"
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("meaningfulStatsSection")
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("timer.input.title")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 12) {
                durationField(
                    titleKey: "timer.input.hours",
                    text: $hoursText,
                    identifier: "hoursField",
                    focus: .hours
                )

                durationField(
                    titleKey: "timer.input.minutes",
                    text: $minutesText,
                    identifier: "minutesField",
                    focus: .minutes
                )

                Button(action: startTimer) {
                    Label("timer.start", systemImage: "play.fill")
                        .frame(minWidth: 92)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityIdentifier("startTimerButton")
            }

            if let inputError {
                Label(LocalizedStringKey(inputError.localizedKey), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("inputErrorLabel")
            }
        }
    }

    private func durationField(
        titleKey: LocalizedStringKey,
        text: Binding<String>,
        identifier: String,
        focus: TimerInputField
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("0", text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(.title3, design: .rounded).monospacedDigit())
                .frame(width: 84)
                .focused($focusedField, equals: focus)
                .accessibilityIdentifier(identifier)
        }
    }

    @ViewBuilder
    private var recentDurationsSection: some View {
        if !store.recentDurations.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("timer.recent.title")
                    .font(.headline)

                HStack(spacing: 8) {
                    ForEach(store.recentDurations, id: \.self) { duration in
                        Button {
                            store.startTimer(durationMinutes: duration)
                            inputError = nil
                        } label: {
                            Text(TimerDurationFormatter.compact(minutes: duration))
                                .monospacedDigit()
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(Text(timerAccessibilityLabel(for: duration)))
                        .accessibilityIdentifier("recentTimerButton_\(duration)")
                    }
                }
            }
        }
    }

    private var timerList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("timer.list.title")
                    .font(.headline)

                Spacer()

                if !store.completedTimers.isEmpty {
                    Button(role: .destructive) {
                        store.clearCompletedTimers()
                    } label: {
                        Label("timer.clearCompleted", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("clearCompletedButton")
                }
            }

            if store.timers.isEmpty {
                ContentUnavailableView(
                    "timer.empty.title",
                    systemImage: "timer",
                    description: Text("timer.empty.description")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("emptyTimerState")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.timers) { timer in
                            TimerRowView(
                                timer: timer,
                                now: store.now,
                                pauseOrResume: {
                                    if timer.state == .paused {
                                        store.resumeTimer(id: timer.id)
                                    } else {
                                        store.pauseTimer(id: timer.id)
                                    }
                                },
                                restart: {
                                    store.restartTimer(id: timer.id)
                                },
                                delete: {
                                    store.deleteTimer(id: timer.id)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .accessibilityIdentifier("timerList")
            }
        }
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

private struct MeaningfulStatCard: View {
    let titleKey: LocalizedStringKey
    let value: String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }
}
