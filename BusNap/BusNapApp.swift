import SwiftUI

@main
struct BusNapApp: App {

    @State private var viewModel = MapDashboardViewModel()
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            MapDashboardView(viewModel: viewModel)
                .onChange(of: scenePhase) { _, newPhase in
                    viewModel.handleScenePhase(newPhase)
                }
        }
    }
}
