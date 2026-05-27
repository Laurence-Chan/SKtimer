import SwiftUI

struct MeaningfulPromptView: View {
    let prompt: PendingMeaningfulPrompt
    let answer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.small, style: .continuous))

                Text("meaningful.prompt.title")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("meaningful.prompt.question")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    String(
                        format: String(localized: "meaningful.prompt.duration"),
                        TimerDurationFormatter.compact(seconds: prompt.durationSeconds)
                    )
                )
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .frame(width: 390)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("meaningfulPromptWindow")
    }
}
