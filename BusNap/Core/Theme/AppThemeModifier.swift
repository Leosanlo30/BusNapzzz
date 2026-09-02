import SwiftUI

/// Legacy card modifier, now routed through the ThemeManager.
/// In Liquid Glass mode it renders a full glass surface; in Light/Dark
/// modes it uses strict semantic colors.
struct AppThemeModifier: ViewModifier {
    @Environment(ThemeManager.self) private var theme

    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 12) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        switch theme.mode {
        case .liquidGlass:
            content.glassSurface(cornerRadius: cornerRadius)
        case .light, .dark:
            content
                .background(
                    Color(UIColor.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        }
    }
}

extension View {
    func themeCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(AppThemeModifier(cornerRadius: cornerRadius))
    }
}
