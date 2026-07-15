import SwiftUI

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .liquidGlass
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
