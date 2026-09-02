import SwiftUI
import MapKit
import CoreLocation

/// Root dashboard. The Map layer and the bottom sheet are deliberately
/// separated: `MapCanvas` only reads map-specific view-model properties,
/// so sheet state transitions (Initial → Configuring → Active) never
/// invalidate or redraw the Map.
@MainActor
struct MapDashboardView: View {

    @Bindable var viewModel: MapDashboardViewModel
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MapCanvas(
                destination: viewModel.selectedDestination,
                leadTimeMinutes: viewModel.leadTime.minutes,
                onSelectCoordinate: { coordinate in
                    let newDestination = Destination(
                        name: "Punto Seleccionado",
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                    viewModel.updateDestination(newDestination)
                },
                onRegionChange: { viewModel.updateVisibleRegion($0) }
            )
            .ignoresSafeArea()

            VStack(alignment: .trailing, spacing: 12) {
                if viewModel.isOffline {
                    offlineBanner
                        .zIndex(1)
                }

                floatingSettingsButton
            }
            .padding(.top, 8)
            .padding(.trailing, 12)
        }
        .sheet(isPresented: $viewModel.showSheet) {
            BottomSheetContent(viewModel: viewModel)
                .presentationDetents(
                    viewModel.currentDetents,
                    selection: $viewModel.selectedDetent
                )
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(true)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
    }

    /// Apple Maps-style floating glass control, independent of sheet state.
    private var floatingSettingsButton: some View {
        Button(action: {
            viewModel.showSettings = true
        }) {
            Image(systemName: "gearshape")
                .font(.title3.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
                .floatingMapControl()
        }
        .buttonStyle(.hapticLight)
        .accessibilityLabel("Configuración")
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .symbolRenderingMode(.multicolor)
            Text("Sin conexión. Las estimaciones podrían fallar.")
                .font(.footnote)
                .fontWeight(.medium)
        }
        .padding(10)
        .themeCard(cornerRadius: 14)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.busnapSpring, value: viewModel.isOffline)
    }
}

// MARK: - Isolated Map Canvas
//
// Receives plain values + closures instead of the whole view model.
// Only changes to `destination` or `leadTimeMinutes` re-evaluate this
// body — sheet state, search text, detents, etc. never touch it.

@MainActor
private struct MapCanvas: View {

    let destination: Destination?
    let leadTimeMinutes: Int
    let onSelectCoordinate: (CLLocationCoordinate2D) -> Void
    let onRegionChange: (MKCoordinateRegion) -> Void

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                UserAnnotation()

                if let dest = destination {
                    let leadTimeSeconds = Double(leadTimeMinutes * 60)
                    let estimatedSpeedPointsPerSecond: Double = 5.5
                    let dynamicRadius = max(500.0, leadTimeSeconds * estimatedSpeedPointsPerSecond)

                    Marker(
                        dest.name ?? "Destino Marcado",
                        monogram: Text(Image(systemName: "mappin")),
                        coordinate: CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude)
                    )
                    .tint(AppConstants.Colors.primaryAccent)

                    MapCircle(
                        center: CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude),
                        radius: dynamicRadius
                    )
                    .foregroundStyle(AppConstants.Colors.primaryAccent.opacity(0.15))
                    .stroke(AppConstants.Colors.primaryAccent, lineWidth: 2)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .onTapGesture { position in
                guard let coordinate = proxy.convert(position, from: .local) else { return }
                onSelectCoordinate(coordinate)
            }
            .safeAreaPadding(.top, 100)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapPitchToggle()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                onRegionChange(context.region)
            }
        }
    }
}
