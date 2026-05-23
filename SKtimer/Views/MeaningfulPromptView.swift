import SwiftUI

struct MeaningfulPromptView: View {
    let prompt: PendingMeaningfulPrompt
    let answer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("meaningful.prompt.title")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("meaningful.prompt.question")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    String(
                        format: String(localized: "meaningful.prompt.duration"),
                        TimerDurationFormatter.compact(seconds: prompt.durationSeconds)
                    )
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            HStack(spacing: 10) {
                Button {
                    answer(false)
                } label: {
                    Text("meaningful.no")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("meaningfulNoButton")

                Button {
                    answer(true)
                } label: {
                    Text("meaningful.yes")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("meaningfulYesButton")
            }
        }
        .padding(24)
        .frame(width: 360)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("meaningfulPromptWindow")
    }
}
