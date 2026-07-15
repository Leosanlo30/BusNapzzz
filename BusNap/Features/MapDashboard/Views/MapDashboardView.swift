import SwiftUI

@MainActor
struct MapDashboardView: View {

    @Bindable var viewModel: MapDashboardViewModel

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
                viewModel: viewModel
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
    }

    private var sheetBackground: AnyShapeStyle {
        switch viewModel.selectedTheme {
        case .liquidGlass:
            AnyShapeStyle(Material.ultraThinMaterial)
        default:
            AnyShapeStyle(Color(UIColor.systemBackground))
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
