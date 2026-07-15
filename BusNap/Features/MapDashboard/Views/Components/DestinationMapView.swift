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
            .safeAreaPadding(.top, 80)
        }
        .ignoresSafeArea(edges: .all)
    }
}
