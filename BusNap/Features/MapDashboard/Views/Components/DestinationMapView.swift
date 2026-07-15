import SwiftUI
import MapKit

@MainActor
struct DestinationMapView: View {
    var viewModel: MapDashboardViewModel
    
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    
    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                UserAnnotation()

                if let dest = viewModel.selectedDestination {
                    let leadTimeSeconds = Double(viewModel.leadTime.minutes * 60)
                    let estimatedSpeedPointsPerSecond: Double = 5.5
                    let dynamicRadius = max(500.0, leadTimeSeconds * estimatedSpeedPointsPerSecond)

                    Marker(
                        dest.name ?? "Destino Marcado",
                        coordinate: CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude)
                    )
                    .tint(.blue)

                    MapCircle(
                        center: CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude),
                        radius: dynamicRadius
                    )
                    .foregroundStyle(.blue.opacity(0.15))
                    .stroke(.blue, lineWidth: 2)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .onTapGesture { position in
                if let coordinate = proxy.convert(position, from: .local) {
                    let newDestination = Destination(
                        name: "Punto Seleccionado",
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                    viewModel.updateDestination(newDestination)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapPitchToggle()
            }
            .safeAreaPadding(.top, 100)
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    settingsButton
                }
                .padding(.top, 112)
                .padding(.trailing, 8)
            }
        }
        .ignoresSafeArea(edges: .all)
    }

    private var settingsButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.showSettings = true
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18))
                .foregroundColor(AppConstants.Colors.primaryAccent)
                .frame(width: 40, height: 40)
                .background(Material.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.hapticLight)
    }
}
