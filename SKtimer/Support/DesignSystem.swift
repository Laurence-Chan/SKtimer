import SwiftUI

enum DesignSystem {
    enum Radius {
        static let small: CGFloat = 8
        static let card: CGFloat = 10
        static let large: CGFloat = 12
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
        static let xxl: CGFloat = 14
        static let xxxl: CGFloat = 16
        static let panel: CGFloat = 20
    }
}

extension Color {
    static let urgencyWarning = Color.orange
    static let urgencyCritical = Color.red
    static let statePaused = Color.orange
    static let stateCompleted = Color.green
    static let borderSubtle = Color.primary.opacity(0.06)
    static let borderMedium = Color.primary.opacity(0.12)
}

struct CardModifier: ViewModifier {
    var fill: Material = .regularMaterial
    var border: Color = .borderSubtle
    var radius: CGFloat = DesignSystem.Radius.card

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            }
    }
}

extension View {
    func card(
        fill: Material = .regularMaterial,
        border: Color = .borderSubtle,
        radius: CGFloat = DesignSystem.Radius.card
    ) -> some View {
        modifier(CardModifier(fill: fill, border: border, radius: radius))
    }
}
