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
                .preferredColorScheme(colorScheme)
                .environment(\.theme, viewModel.selectedTheme)
                .onChange(of: scenePhase) { _, newPhase in
                    viewModel.handleScenePhase(newPhase)
                }
        }
    }
}
