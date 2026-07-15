import SwiftUI

@MainActor
struct MapDashboardView: View {

    @Bindable var viewModel: MapDashboardViewModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DestinationMapView(viewModel: viewModel)

            settingsButton
                .padding(16)
                .zIndex(2)

            if viewModel.isOffline {
                offlineBanner
                    .zIndex(1)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .sheet(isPresented: $viewModel.showSheet) {
            BottomSheetContent(viewModel: viewModel)
                .presentationDetents(
                    viewModel.currentDetents,
                    selection: $viewModel.selectedDetent
                )
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(true)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
    }

    private var settingsButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.showSettings = true
        }) {
            Image(systemName: "gearshape.fill")
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.hapticLight)
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
