import SwiftUI

struct GlassPalette {
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let backgroundGradientTop: Color
    let backgroundGradientBottom: Color
    let cardFill: AnyShapeStyle
    let cardStroke: Color
    let rowFill: Color

    @MainActor
    init(theme: ThemeSettings) {
        switch theme.selectedTheme {
        case .nord:
            primaryText = theme.nordPrimaryText
            secondaryText = theme.nordSecondaryText
            accent = theme.nordAccent
            backgroundGradientTop = theme.nordBackground
            backgroundGradientBottom = theme.nordSecondaryBackground
            cardFill = AnyShapeStyle(theme.nordCardBackground.opacity(0.72))
            cardStroke = theme.nordAccent.opacity(0.35)
            rowFill = theme.nordCardBackground.opacity(0.9)
        case .sepia:
            primaryText = theme.sepiaPrimaryText
            secondaryText = theme.sepiaSecondaryText
            accent = theme.sepiaAccent
            backgroundGradientTop = theme.sepiaBackground
            backgroundGradientBottom = theme.sepiaSecondaryBackground
            cardFill = AnyShapeStyle(theme.sepiaCardBackground.opacity(0.80))
            cardStroke = theme.sepiaAccent.opacity(0.30)
            rowFill = theme.sepiaCardBackground.opacity(0.85)
        case .outrun:
            primaryText = theme.outrunPrimaryText
            secondaryText = theme.outrunSecondaryText
            accent = theme.outrunAccent
            backgroundGradientTop = theme.outrunBackground
            backgroundGradientBottom = theme.outrunSecondaryBackground
            cardFill = AnyShapeStyle(theme.outrunCardBackground.opacity(0.80))
            cardStroke = theme.outrunAccent.opacity(0.50)
            rowFill = theme.outrunCardBackground.opacity(0.9)
        case .cyber:
            primaryText = theme.cyberPrimaryText
            secondaryText = theme.cyberSecondaryText
            accent = theme.cyberAccent
            backgroundGradientTop = theme.cyberBackground
            backgroundGradientBottom = theme.cyberSecondaryBackground
            cardFill = AnyShapeStyle(theme.cyberCardBackground.opacity(0.85))
            cardStroke = theme.cyberAccent.opacity(0.50)
            rowFill = theme.cyberCardBackground.opacity(0.9)
        case .snow:
            primaryText = theme.snowPrimaryText
            secondaryText = theme.snowSecondaryText
            accent = theme.snowAccent
            backgroundGradientTop = theme.snowBackground
            backgroundGradientBottom = theme.snowSecondaryBackground
            cardFill = AnyShapeStyle(theme.snowCardBackground.opacity(0.80))
            cardStroke = theme.snowAccent.opacity(0.35)
            rowFill = theme.snowCardBackground.opacity(0.9)
        case .jungle:
            primaryText = theme.junglePrimaryText
            secondaryText = theme.jungleSecondaryText
            accent = theme.jungleAccent
            backgroundGradientTop = theme.jungleBackground
            backgroundGradientBottom = theme.jungleSecondaryBackground
            cardFill = AnyShapeStyle(theme.jungleCardBackground.opacity(0.82))
            cardStroke = theme.jungleAccent.opacity(0.40)
            rowFill = theme.jungleCardBackground.opacity(0.9)
        default:
            primaryText = .primary
            secondaryText = .secondary
            accent = .blue
            backgroundGradientTop = Color(.systemBackground)
            backgroundGradientBottom = Color(.secondarySystemBackground)
            cardFill = AnyShapeStyle(.ultraThinMaterial)
            cardStroke = Color.white.opacity(0.35)
            rowFill = Color.white.opacity(0.10)
        }
    }
}

private struct GlassCardModifier: ViewModifier {
    let palette: GlassPalette
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
    }
}

extension View {
    func glassCard(_ palette: GlassPalette, cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(palette: palette, cornerRadius: cornerRadius))
    }
}
