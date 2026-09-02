//
//  LiquidGlassModifiers.swift
//  BusNap
//
//  Custom ViewModifiers implementing the "Liquid Glass" surface system.
//  - Outer surfaces: `.ultraThinMaterial` so the live map blurs through.
//  - Inner grouped containers: `Color.clear` (no double-blur stacking).
//  - Edge lighting: subtle `.white.opacity(0.15)` strokes on every glass edge.
//

import SwiftUI

// MARK: - Glass Surface Modifier

/// The primary Liquid Glass surface. Applied to cards, bars, and the sheet
/// chrome. In Light/Dark themes this degrades gracefully to semantic colors.
struct GlassSurfaceModifier: ViewModifier {
    @Environment(ThemeManager.self) private var theme

    var cornerRadius: CGFloat = 16
    var padding: EdgeInsets = EdgeInsets(
        top: AppConstants.Layout.standardPadding,
        leading: AppConstants.Layout.standardPadding,
        bottom: AppConstants.Layout.standardPadding,
        trailing: AppConstants.Layout.standardPadding
    )

    func body(content: Content) -> some View {
        switch theme.mode {
        case .liquidGlass:
            content
                .background(.clear)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        case .light:
            content
                .background(Color(UIColor.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        case .dark:
            content
                .background(Color(UIColor.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

// MARK: - Floating Map Control Modifier

/// Circular floating control used for map overlays (Apple Maps-style buttons).
struct FloatingMapControlModifier: ViewModifier {
    @Environment(ThemeManager.self) private var theme

    func body(content: Content) -> some View {
        content
            .frame(width: 44, height: 44)
            .modifier(GlassSurfaceModifier(cornerRadius: 22))
            .symbolRenderingMode(.hierarchical)
    }
}

// MARK: - View Extensions

extension View {

    /// Liquid Glass card. In native modes it falls back to semantic colors.
    /// Inner grouped containers should use `.innerClearContainer()` instead
    /// so the map blurs through without stacking materials.
    func glassSurface(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassSurfaceModifier(cornerRadius: cornerRadius))
    }

    /// A transparent inner container — lets the parent's material do the
    /// work in Liquid Glass mode; semantic fill in native modes.
    func innerClearContainer(cornerRadius: CGFloat = 12) -> some View {
        modifier(InnerClearContainerModifier(cornerRadius: cornerRadius))
    }

    /// Floating circular map button with edge-lighting stroke.
    func floatingMapControl() -> some View {
        modifier(FloatingMapControlModifier())
    }
}

// MARK: - Inner Container Modifier

struct InnerClearContainerModifier: ViewModifier {
    @Environment(ThemeManager.self) private var theme

    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        switch theme.mode {
        case .liquidGlass:
            // Deliberately clear: the parent's .ultraThinMaterial blurs the
            // map through this container — no stacked materials.
            content.background(Color.clear)
        case .light, .dark:
            content.background(
                Color(UIColor.tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }
}

// MARK: - Shared Motion Constants

extension Animation {
    /// The signature BusNap spring — fluid, Apple-native feel.
    static var busnapSpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.75)
    }

    /// Slightly snappier variant for small state changes (filters, chips).
    static var busnapSnap: Animation {
        .spring(response: 0.3, dampingFraction: 0.8)
    }
}
