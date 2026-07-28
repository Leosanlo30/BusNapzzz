import SwiftUI
import MapKit

// -----------------------------------------------------------
//  (DESACTIVADO) Anotaciones de paraderos – se mantiene el código
//  para futura re-activación.
// -----------------------------------------------------------
//@MainActor
//struct BusStopAnnotation: View {
//    let stop: BusStop
//    let scale: CGFloat
//    let isSelected: Bool
//
//    private var baseSize: CGFloat { max(14, 20 * scale) }
//    private var iconSize: CGFloat { max(7, 10 * scale) }
//    private var strokeWidth: CGFloat { max(1.5, 2.5 * scale) }
//
//    var body: some View {
//        let bg = Circle()
//            .fill(.white)
//            .frame(width: baseSize, height: baseSize)
//            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
//        let ring = Circle()
//            .stroke(isSelected ? Color.orange : Color.blue, lineWidth: strokeWidth)
//            .frame(width: baseSize, height: baseSize)
//        let icon = Image(systemName: "bus.fill")
//            .font(.system(size: iconSize, weight: .semibold))
//            .foregroundColor(isSelected ? .orange : .blue)
//
//        return ZStack(content: { bg; ring; icon })
//            .padding(24)
//            .contentShape(Rectangle())
//            .drawingGroup()
//    }
//}
//
//@MainActor
//struct StopCallout: View {
//    let name: String
//    @Environment(\.theme) private var theme
//
//    var body: some View {
//        HStack(spacing: 6) {
//            Image(systemName: "bus.fill")
//                .font(.caption)
//                .foregroundColor(AppConstants.Colors.primaryAccent)
//            Text(name)
//                .font(.footnote)
//                .fontWeight(.semibold)
//                .foregroundColor(AppConstants.Colors.primaryText)
//                .lineLimit(1)
//        }
//        .padding(.horizontal, 12)
//        .padding(.vertical, 6)
//        .background(theme.cardBackgroundStyle)
//        .cornerRadius(8)
//        .overlay(
//            RoundedRectangle(cornerRadius: 8)
//                .stroke(theme.cardBorderColor, lineWidth: theme.cardBorderWidth)
//        )
//    }
//}

@MainActor
struct DestinationMapView: View {
    @Bindable var viewModel: MapDashboardViewModel

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                UserAnnotation()

                // (DESACTIVADO) Anotaciones de paraderos en el mapa
//                ForEach(viewModel.stopsInSight, id: \.id) { stop in
//                    let isSel = viewModel.selectedStop?.id == stop.id
//                    Annotation(stop.name, coordinate: stop.coordinate) {
//                        VStack(spacing: 2) {
//                            BusStopAnnotation(
//                                stop: stop,
//                                scale: viewModel.stopAnnotationScale,
//                                isSelected: isSel
//                            )
//                            if isSel {
//                                StopCallout(name: stop.name)
//                            }
//                        }
//                    }
//                    .annotationTitles(.hidden)
//                }

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
                guard let coordinate = proxy.convert(position, from: .local) else { return }
                // (DESACTIVADO) Detección de parada cercana – se coloca destino directamente
                let newDestination = Destination(
                    name: "Punto Seleccionado",
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                viewModel.updateDestination(newDestination)
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapPitchToggle()
            }
            .safeAreaPadding(.top, 100)
            // AQUI: Botón de configuración ajustado en tamaño y posición para evitar colisiones.
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    settingsButton
                        .padding(.top, 4)
                }
                .padding(.top, 140)
                .padding(.trailing, 12)
            }
            // (DESACTIVADO) Navegación a cámara de ruta
//            .onChange(of: viewModel.selectedRoute) { _, newRoute in
//                if newRoute != nil, let position = viewModel.routeSearchCamera {
//                    withAnimation(.easeInOut(duration: 0.6)) {
//                        cameraPosition = position
//                    }
//                }
//            }
            .onMapCameraChange(frequency: .onEnd) { context in
                viewModel.updateVisibleRegion(context.region)
            }
        }
        .ignoresSafeArea(edges: .all)
    }

    @Environment(\.theme) private var theme

    private var settingsButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.showSettings = true
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 22))
                .foregroundColor(AppConstants.Colors.primaryAccent)
                .frame(width: 44, height: 44)
                .background(theme.cardBackgroundStyle)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(theme.cardBorderColor, lineWidth: theme.cardBorderWidth)
                )
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.hapticLight)
    }
}

