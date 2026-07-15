import SwiftUI

@MainActor
struct MapDashboardView: View {

    @Bindable var viewModel: MapDashboardViewModel
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DestinationMapView(viewModel: viewModel)

            if viewModel.isOffline {
                offlineBanner
                    .zIndex(1)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .sheet(isPresented: $viewModel.showSheet) {
            BottomSheetContent(
                viewModel: viewModel,
                onOpenSettings: openSettings
            )
            .presentationDetents(
                viewModel.currentDetents,
                selection: $viewModel.selectedDetent
            )
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(true)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
            .presentationBackground(sheetBackground)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
                .onDisappear {
                    viewModel.showSheet = true
                }
        }
    }

    private var sheetBackground: AnyShapeStyle {
        switch viewModel.selectedTheme {
        case .liquidGlass:
            AnyShapeStyle(Material.ultraThinMaterial)
        default:
            AnyShapeStyle(Color(UIColor.systemBackground))
        }
    }

    private func openSettings() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        viewModel.showSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showSettings = true
        }
    }

    private var offlineBanner: some View {
        VStack {
            HStack {
                Image(systemName: "wifi.slash")
                Text("Sin conexión. Las estimaciones podrían fallar.")
                    .font(.footnote)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))

            Spacer()
        }
        .animation(.easeInOut, value: viewModel.isOffline)
    }
}
