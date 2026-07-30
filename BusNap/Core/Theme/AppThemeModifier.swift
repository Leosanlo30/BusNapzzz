import SwiftUI

struct AppThemeModifier: ViewModifier {
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 12) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(cornerRadius)
    }
}

extension View {
    func themeCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(AppThemeModifier(cornerRadius: cornerRadius))
    }
}
