import UIKit

enum ThemeApplier {
    static func apply(_ theme: AppTheme) {
        let style: UIUserInterfaceStyle
        switch theme {
        case .light:  style = .light
        case .dark:   style = .dark
        case .system: style = .unspecified
        }
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.overrideUserInterfaceStyle = style }
    }
}
