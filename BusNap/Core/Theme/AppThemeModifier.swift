import SwiftUI

// MARK: - AppThemeModifier

/// Modificador de tema reutilizable para tarjetas y paneles.
///
/// Aplica automáticamente:
/// - El fondo según `AppTheme` (negro puro para Dark, `.ultraThinMaterial` para Liquid Glass,
///   fondo secundario del sistema para los demás).
/// - El borde reflectante (blanco semitransparente para Liquid Glass, `.primary` opaco para los demás).
/// - La esquina redondeada y el grosor de borde correspondientes.
///
/// Uso básico:
/// ```swift
/// Text("Hola")
///     .padding(12)
///     .modifier(AppThemeModifier(cornerRadius: 12))
/// ```
struct AppThemeModifier: ViewModifier {

    let cornerRadius: CGFloat
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.liquidGlass.rawValue

    private var theme: AppTheme {
        AppTheme(rawValue: appThemeRaw) ?? .liquidGlass
    }

    init(cornerRadius: CGFloat = 12) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background(theme.cardBackgroundStyle)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(theme.cardBorderColor, lineWidth: theme.cardBorderWidth)
            )
    }
}

// MARK: - View Extension

extension View {

    /// Aplica el estilo de tarjeta temática con la esquina redondeada especificada.
    func themeCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(AppThemeModifier(cornerRadius: cornerRadius))
    }
}
