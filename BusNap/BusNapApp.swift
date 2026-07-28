import SwiftUI

@main
struct BusNapApp: App {

    @State private var viewModel = MapDashboardViewModel()
    @Environment(\.scenePhase) var scenePhase

    private var colorScheme: ColorScheme? {
        switch viewModel.selectedTheme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            MapDashboardView(viewModel: viewModel)
                .id(viewModel.selectedTheme)
                .preferredColorScheme(colorScheme)
                .environment(\.theme, viewModel.selectedTheme)
                .transaction { $0.animation = nil }
                .onAppear { viewModel.applyPersistedThemeToWindows() }
                .onChange(of: scenePhase) { _, newPhase in
                    viewModel.handleScenePhase(newPhase)
                }
        }
    }
}
