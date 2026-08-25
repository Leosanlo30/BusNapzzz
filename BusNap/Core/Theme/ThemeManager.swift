//
//  ThemeManager.swift
//  BusNap
//
//  Central theming engine. Supports three explicit modes:
//  - .liquidGlass: Glassmorphism over the live map (materials + edge lighting)
//  - .light / .dark: Strict native semantic colors
//
//  Mode switching is applied at the UIWindow layer
//  (`overrideUserInterfaceStyle`), which bypasses SwiftUI's implicit
//  color cross-fade animations entirely — rendering is instantaneous.
//

import SwiftUI
import Observation

enum AppThemeMode: String, CaseIterable, Identifiable {
    case liquidGlass
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .liquidGlass: return "Liquid Glass"
        case .light: return "Claro"
        case .dark: return "Oscuro"
        }
    }

    var icon: String {
        switch self {
        case .liquidGlass: return "square.stack.3d.up.fill"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    /// `nil` means "follow the system appearance" (Liquid Glass mode).
    var overriddenColorScheme: ColorScheme? {
        switch self {
        case .liquidGlass: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
@Observable
final class ThemeManager {

    static let shared = ThemeManager()

    private static let storageKey = "busnap.themeMode"

    /// The active theme mode. Persisted across launches.
    var mode: AppThemeMode {
        didSet {
            guard oldValue != mode else { return }
            UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
            applyToWindows()
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        mode = raw.flatMap(AppThemeMode.init(rawValue:)) ?? .liquidGlass
    }

    // MARK: - Zero-Lag Switching

    /// Pushes the override straight onto every window's render tree.
    /// UIKit applies this synchronously on the next frame with no implicit
    /// animation, so Light/Dark/Liquid Glass flips are 100% instantaneous.
    func applyToWindows() {
        let style: UIUserInterfaceStyle
        switch mode.overriddenColorScheme {
        case .light: style = .light
        case .dark: style = .dark
        case nil: style = .unspecified
        @unknown default: style = .unspecified
        }

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                UIView.performWithoutAnimation {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }

    /// Call once from the App struct after the first window exists.
    func activate() {
        applyToWindows()
    }
}
