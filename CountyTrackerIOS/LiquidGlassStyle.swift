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
        if theme.isNord {
            primaryText = theme.nordPrimaryText
            secondaryText = theme.nordSecondaryText
            accent = theme.nordAccent
            backgroundGradientTop = theme.nordBackground
            backgroundGradientBottom = theme.nordSecondaryBackground
            cardFill = AnyShapeStyle(theme.nordCardBackground.opacity(0.72))
            cardStroke = theme.nordAccent.opacity(0.35)
            rowFill = theme.nordCardBackground.opacity(0.9)
        } else {
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
