import SwiftUI
import MapKit
import CoreLocation

/// Root dashboard. The Map layer and the bottom sheet are deliberately
/// separated: `MapCanvas` only receives plain map values, so sheet state
/// transitions (Initial → Configuring → Active) never redraw the Map.
@MainActor
struct MapDashboardView: View {

    @Bindable var viewModel: MapDashboardViewModel
    @Environment(ThemeManager.self) private var theme
    @Namespace private var mapScope

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MapCanvas(
                mapScope: mapScope,
                destination: viewModel.selectedDestination,
                alarmRadius: viewModel.alarmRadius,
                routePath: viewModel.routePath,
                isTripActive: viewModel.isTripActive,
                followsUser: viewModel.settings.followsUserDuringTrip,
                appearance: MapAppearance(settings: viewModel.settings),
                onTap: { viewModel.handleMapTap(at: $0) },
                onRegionChange: { viewModel.updateVisibleRegion($0) }
            )
            .ignoresSafeArea()

            VStack(alignment: .trailing, spacing: 12) {
                if viewModel.isOffline {
                    offlineBanner
                        .zIndex(1)
                }

                // Columna única de controles, como en Apple Maps: los botones
                // nativos del mapa se enlazan a través de `mapScope`.
                VStack(spacing: 0) {
                    floatingSettingsButton
                    Divider().frame(width: 28)
                    MapStyleMenu(settings: viewModel.settings)
                }
                .modifier(GlassSurfaceModifier(cornerRadius: 22))

                VStack(spacing: 10) {
                    MapUserLocationButton(scope: mapScope)
                    MapPitchToggle(scope: mapScope)
                    MapCompass(scope: mapScope)
                }
                .buttonBorderShape(.circle)
            }
            .padding(.top, 8)
            .padding(.trailing, 12)
            .animation(.busnapSpring, value: viewModel.isOffline)
        }
        .mapScope(mapScope)
        .onAppear { viewModel.onAppear() }
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

    private var floatingSettingsButton: some View {
        Button {
            viewModel.showSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.title3.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.hapticLight)
        .accessibilityLabel("Configuración")
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .symbolRenderingMode(.multicolor)
            Text("Sin conexión. La alarma sigue activa; el tiempo estimado puede no actualizarse.")
                .font(.footnote)
                .fontWeight(.medium)
        }
        .padding(10)
        .frame(maxWidth: 280, alignment: .leading)
        .themeCard(cornerRadius: 14)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Map Style Menu

/// Selector rápido del tipo de mapa y capas, como el botón de mapas de Apple Maps.
private struct MapStyleMenu: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Menu {
            Picker("Tipo de mapa", selection: $settings.mapStyle) {
                ForEach(MapStyleOption.allCases) { option in
                    Label(option.label, systemImage: option.icon).tag(option)
                }
            }
            Section("Capas") {
                Toggle(isOn: $settings.showsTraffic) {
                    Label("Tráfico", systemImage: "car.2")
                }
                Toggle(isOn: $settings.showsTransitStops) {
                    Label("Paradas de transporte", systemImage: "bus")
                }
                Toggle(isOn: $settings.showsRealisticElevation) {
                    Label("Edificios en 3D", systemImage: "building.2")
                }
            }
        } label: {
            Image(systemName: settings.mapStyle.icon)
                .font(.title3.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Tipo de mapa")
    }
}

// MARK: - Map Appearance

/// Valores de estilo del mapa. `Equatable` para que el `MapCanvas` solo se
/// reevalúe cuando cambian de verdad.
struct MapAppearance: Equatable {
    let style: MapStyleOption
    let showsTraffic: Bool
    let showsTransitStops: Bool
    let realisticElevation: Bool

    @MainActor
    init(settings: AppSettings) {
        style = settings.mapStyle
        showsTraffic = settings.showsTraffic
        showsTransitStops = settings.showsTransitStops
        realisticElevation = settings.showsRealisticElevation
    }

    var mapStyle: MapStyle {
        let elevation: MapStyle.Elevation = realisticElevation ? .realistic : .flat
        let pointsOfInterest: PointOfInterestCategories = showsTransitStops
            ? .including([.publicTransport])
            : .excludingAll

        switch style {
        case .standard:
            return .standard(elevation: elevation, pointsOfInterest: pointsOfInterest, showsTraffic: showsTraffic)
        case .transit:
            return .standard(elevation: elevation, emphasis: .muted,
                             pointsOfInterest: .including([.publicTransport]), showsTraffic: showsTraffic)
        case .hybrid:
            return .hybrid(elevation: elevation, pointsOfInterest: pointsOfInterest, showsTraffic: showsTraffic)
        case .satellite:
            return .imagery(elevation: elevation)
        }
    }
}

// MARK: - Isolated Map Canvas
//
// Receives plain values + closures instead of the whole view model, so
// sheet state, search text, detents, etc. never touch it.

@MainActor
private struct MapCanvas: View {

    let mapScope: Namespace.ID
    let destination: Destination?
    let alarmRadius: CLLocationDistance
    let routePath: [RouteCoordinate]
    let isTripActive: Bool
    let followsUser: Bool
    let appearance: MapAppearance
    let onTap: (CLLocationCoordinate2D) -> Void
    let onRegionChange: (MKCoordinateRegion) -> Void

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    private var accent: Color { AppConstants.Colors.primaryAccent }

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, scope: mapScope) {
                UserAnnotation()

                if routePath.count > 1 {
                    MapPolyline(coordinates: routePath.map(\.coordinate))
                        .stroke(accent.opacity(0.85),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }

                if let destination {
                    // Zona de alarma: al entrar en ella suena el despertador.
                    MapCircle(center: destination.coordinate, radius: alarmRadius)
                        .foregroundStyle(accent.opacity(isTripActive ? 0.18 : 0.10))
                        .stroke(accent, style: StrokeStyle(lineWidth: 2, dash: isTripActive ? [] : [6, 4]))

                    Marker(destination.name ?? "Destino",
                           systemImage: isTripActive ? "bell.and.waves.left.and.right.fill" : "mappin",
                           coordinate: destination.coordinate)
                        .tint(accent)
                }
            }
            .mapStyle(appearance.mapStyle)
            .onTapGesture { position in
                guard let coordinate = proxy.convert(position, from: .local) else { return }
                onTap(coordinate)
            }
            .mapControls {
                // Los botones de ubicación, 3D y brújula viven en la columna flotante.
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                onRegionChange(context.region)
            }
            .onChange(of: routePath) { _, newPath in
                guard !isTripActive || !followsUser else { return }
                frame(newPath)
            }
            .onChange(of: destination) { _, newDestination in
                guard let newDestination, routePath.isEmpty, !isTripActive else { return }
                withAnimation(.easeInOut(duration: 0.6)) {
                    cameraPosition = .camera(MapCamera(centerCoordinate: newDestination.coordinate,
                                                       distance: max(alarmRadius * 5, 3_000)))
                }
            }
            .onChange(of: isTripActive) { _, active in
                guard active, followsUser else { return }
                withAnimation(.easeInOut(duration: 0.8)) {
                    cameraPosition = .userLocation(followsHeading: false, fallback: .automatic)
                }
            }
        }
    }

    /// Encuadra la ruta completa dejando margen para la hoja inferior.
    private func frame(_ path: [RouteCoordinate]) {
        guard path.count > 1 else { return }
        let rect = path.reduce(MKMapRect.null) { partial, point in
            partial.union(MKMapRect(origin: MKMapPoint(point.coordinate), size: MKMapSize(width: 1, height: 1)))
        }
        let padded = rect.insetBy(dx: -rect.size.width * 0.3, dy: -rect.size.height * 0.3)
        // Desplazamos hacia abajo para que la ruta quede por encima de la hoja.
        let shifted = padded.offsetBy(dx: 0, dy: padded.size.height * 0.35)
        withAnimation(.easeInOut(duration: 0.8)) {
            cameraPosition = .rect(shifted)
        }
    }
}
