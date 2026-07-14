import SwiftUI
import MapKit

@MainActor
struct DestinationMapView: View {
    var viewModel: MapDashboardViewModel
    
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    
    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                
                // 1. Muestra el punto azul del usuario
                UserAnnotation()
                
                // Si el usuario ya marcó un destino, dibujamos los elementos
                if let dest = viewModel.selectedDestination {
                    
                    // --- CÁLCULO DEL RADIO DINÁMICO ---
                    // Convertimos los minutos elegidos por el usuario a segundos
                    let leadTimeSeconds = Double(viewModel.leadTime.minutes * 60)
                    
                    // Asumimos una velocidad promedio urbana de 11 m/s (aprox 40 km/h)
                    let estimatedSpeedPointsPerSecond: Double = 5.5
                    
                    // Calculamos el radio dinámico (mínimo 1000m por seguridad de la antena GPS)
                    let dynamicRadius = max(500.0, leadTimeSeconds * estimatedSpeedPointsPerSecond)
                    
                    // 2. El pin clásico del destino
                    Marker(
                        dest.name ?? "Destino Marcado",
                        coordinate: CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude)
                    )
                    .tint(.blue)
                    
                    // 3. NUEVO: El radio visual de la Geocerca adaptable
                    MapCircle(
                        center: CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude),
                        radius: dynamicRadius
                    )
                    .foregroundStyle(.blue.opacity(0.15)) // Relleno suave para no tapar las calles del mapa
                    .stroke(.blue, lineWidth: 2)         // Borde definido para notar el cruce exacto
                }
            }
            
            .safeAreaPadding(.top, 80)
            // Estilo del Mapa unicamente en 2D
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            
            //Gestos de pantalla del mapa
            .onTapGesture { position in
                if let coordinate = proxy.convert(position, from: .local) {
                    let newDestination = Destination(
                        name: "Punto Seleccionado",
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                    viewModel.updateDestination(newDestination)
                }
                //Controles del mapa
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapPitchToggle()
            }
        }
        .ignoresSafeArea(edges: .all)
    }
}
