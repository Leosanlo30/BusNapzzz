//
//  MapDashboardViewModel.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 08/07/26.
//

import Foundation
import SwiftUI
import Observation
import CoreLocation
import MapKit

// MARK: - MapDashboardViewModel

/// ViewModel central de la pantalla del mapa.
///
/// ``MapDashboardViewModel`` gestiona toda la lógica de negocio para:
/// - Búsqueda de lugares reales vía MKLocalSearch (Apple Maps).
/// - Seguimiento de la región visible del mapa.
/// - Selección de destino, favoritos, ciclo de vida del viaje y
///   estados de proximidad adaptativa.
///
/// La clase está anotada con `@MainActor` y `@Observable` para que las
/// vistas SwiftUI observen sus propiedades publicadas directamente.
@MainActor
@Observable
final class MapDashboardViewModel {

    // MARK: - UI State Properties

    /// Whether the trip timer is in a paused state.
    var isPaused: Bool = false

    /// Whether the bottom sheet is presented.
    var showSheet: Bool = true

    /// Whether the settings full-screen cover is presented.
    var showSettings: Bool = false

    /// The currently selected presentation detent for the bottom sheet.
    var selectedDetent: PresentationDetent = .fraction(0.25)

    /// The text currently entered in the search bar.
    var searchText: String = ""

    // MARK: - Resultados de Búsqueda Local (MKLocalSearch)

    /// Resultados en caché para búsquedas offline.
    private var searchCache: [String: [PlaceResult]] = [:]

    /// Resultados de la última búsqueda MKLocalSearch.
    var searchResults: [PlaceResult] = []

    // MARK: - (DESACTIVADO) Propiedades de Paraderos
    // Se mantienen comentadas para activación futura.
//    var busStops: [BusStop] = []
//    var busStopsLoadError: String? = nil
//    var selectedRoute: String? = nil
//    var showRouteSearchResults: Bool = false
//    var selectedStop: BusStop? = nil

    // MARK: - Proximity Properties

    /// Whether the user is within 500 m of the destination stop.
    var isApproachingStop: Bool = false

    /// The current distance from the user to the destination stop, in meters.
    var distanceToStop: CLLocationDistance? = nil

    // MARK: - Map Region Properties

    /// The last known visible region of the map.
    var mapVisibleRegion: MKCoordinateRegion? = nil

    /// The north–south distance (in meters) the map currently covers.
    var mapCameraDistance: CLLocationDistance = 0

    /// The north–south distance (in meters) below which the map is considered "zoomed in".
    private let zoomThresholdMeters: CLLocationDistance = 1_500

    // MARK: - Trip & Destination Properties

    /// The current UI state derived from the trip engine and pause state.
    var tripUIState: TripUIState {
        TripUIState.from(engineState: tripEngine.state, isPaused: isPaused)
    }

    /// The raw trip-engine state.
    var alarmStatus: TripState { tripEngine.state }

    /// The currently selected destination, if any.
    var selectedDestination: Destination? { tripEngine.currentDestination }

    /// The simulated ETA from the current location to the destination, in seconds.
    var simulatedETA: TimeInterval? = nil

    /// The user's configured lead time for the arrival alarm.
    var leadTime: AlertLeadTime = .fiveMinutes

    /// Whether an ETA request is currently in flight.
    var isLoadingETA: Bool = false

    /// A user-facing error message, or `nil`.
    var errorMessage: String? = nil

    /// Whether the device is offline.
    var isOffline: Bool = false

    /// The user-editable display name for the current destination.
    var destinationName: String = ""

    /// The list of user-saved favorite destinations.
    var savedFavorites: [Destination] = []

    /// Whether vibration feedback is enabled for alarms.
    @ObservationIgnored @AppStorage("vibrationEnabled") var vibrationEnabled = true

    /// The name of the ringtone to play for the alarm.
    var ringtoneName: String = "alarm" {
        didSet { UserDefaults.standard.set(ringtoneName, forKey: "ringtoneName") }
    }

    /// A custom lead-time value (in minutes) used when `leadTime == .custom`.
    var customLeadTimeMinutes = 10 {
        didSet { UserDefaults.standard.set(customLeadTimeMinutes, forKey: "customLeadTime") }
    }

    /// The app's current theme — tracked by @Observable for reactive UI updates.
    var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "appTheme")
            preferencesStore.saveTheme(selectedTheme)
        }
    }

    /// The set of detents the bottom sheet can snap to.
    var currentDetents: Set<PresentationDetent> {
        [.fraction(0.25), .medium, .large]
    }

    /// The ideal detent for the current trip UI state.
    var defaultDetent: PresentationDetent {
        switch tripUIState {
        case .initial:     return .fraction(0.25)
        case .configuring: return .medium
        case .active:      return .fraction(0.25)
        case .paused:      return .fraction(0.25)
        case .finished:    return .fraction(0.35)
        }
    }

    // MARK: - Computed: Zoom & Scale

    /// Whether the map camera is zoomed in beyond `zoomThresholdMeters`.
    ///
    /// Uses the north–south distance derived from `mapVisibleRegion`.
    var isZoomedIn: Bool {
        guard let region = mapVisibleRegion else { return false }
        let north = CLLocation(latitude: region.center.latitude + region.span.latitudeDelta / 2,
                               longitude: region.center.longitude)
        let south = CLLocation(latitude: region.center.latitude - region.span.latitudeDelta / 2,
                               longitude: region.center.longitude)
        return north.distance(from: south) < zoomThresholdMeters
    }

    // (DESACTIVADO) Escala de anotaciones de paraderos
//    var stopAnnotationScale: CGFloat {
//        guard mapCameraDistance > 0 else { return 0.35 }
//        let clamped = min(mapCameraDistance, zoomThresholdMeters)
//        let t = clamped / zoomThresholdMeters
//        return CGFloat(0.35 + (1.0 - t) * 0.65)
//    }

    // MARK: - Computed: Search Suggestions

    /// Sugerencias de búsqueda combinando resultados MKLocalSearch y favoritos.
    var searchSuggestions: [SearchSuggestion] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        let favoriteMatches = savedFavorites.filter { fav in
            guard let name = fav.name else { return false }
            return name.localizedCaseInsensitiveContains(query)
        }

        var suggestions: [SearchSuggestion] = []
        for place in searchResults.prefix(10) {
            suggestions.append(.place(place))
        }
        for fav in favoriteMatches.prefix(5) {
            suggestions.append(.favorite(fav))
        }
        return suggestions
    }

    // MARK: - Dependencies

    @ObservationIgnored private let routeEstimator: RouteEstimating
    @ObservationIgnored private let preferencesStore: UserPreferencesStoring
    @ObservationIgnored private let networkMonitor: NetworkMonitoring
    @ObservationIgnored private let locationManager: LocationManaging
    @ObservationIgnored private let tripEngine: TripEngine

    @ObservationIgnored private var lastETARequestTime: Date = .distantPast
    @ObservationIgnored private var isAppInBackground: Bool = false
    @ObservationIgnored private var isFetchingETA: Bool = false

    // MARK: - Initialization

    /// Creates a new view model with the given (or default) dependencies.
    ///
    /// - Parameters:
    ///   - routeEstimator: Service for ETA estimation. Defaults to `MapKitRouteEstimator`.
    ///   - preferencesStore: Persistence for user preferences. Defaults to `UserDefaultsPreferencesStore`.
    ///   - networkMonitor: Reachability monitor. Defaults to `NetworkMonitor`.
    ///   - locationManager: Location service. Defaults to `AdaptiveLocationManager`.
    ///   - tripEngine: Trip state machine. Defaults to `TripEngine`.
    init(
        routeEstimator: RouteEstimating? = nil,
        preferencesStore: UserPreferencesStoring? = nil,
        networkMonitor: NetworkMonitoring? = nil,
        locationManager: LocationManaging? = nil,
        tripEngine: TripEngine? = nil
    ) {
        self.routeEstimator = routeEstimator ?? MapKitRouteEstimator()
        self.preferencesStore = preferencesStore ?? UserDefaultsPreferencesStore()
        self.networkMonitor = networkMonitor ?? NetworkMonitor()
        self.locationManager = locationManager ?? AdaptiveLocationManager()
        self.tripEngine = tripEngine ?? TripEngine()

        self.leadTime = self.preferencesStore.loadLeadTime()
        self.ringtoneName = UserDefaults.standard.string(forKey: "ringtoneName") ?? "alarm"
        self.selectedTheme = self.preferencesStore.loadTheme()

        self.networkMonitor.setStatusHandler { [weak self] offline in
            guard let self = self else { return }
            Task { @MainActor in
                self.isOffline = offline
            }
        }
        self.networkMonitor.start()

        self.savedFavorites = self.preferencesStore.loadFavorites()

        self.locationManager.setLocationHandler { [weak self] newLocation in
            guard let self = self else { return }
            Task { @MainActor in
                self.processLocationUpdate(newLocation)
            }
        }

        // (DESACTIVADO) Carga de paraderos desde GeoJSON
//        loadBusStops()
    }

    // MARK: - Public: Búsqueda Local (MKLocalSearch)

    /// Ejecuta una búsqueda MKLocalSearch con el texto actual y guarda en caché.
    @MainActor
    func performLocalSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        // 1. Intentar cargar desde caché offline primero
        if let cached = loadCachedResults(for: query) {
            self.searchResults = cached
            return
        }

        // 2. Consultar Apple Maps
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region = mapVisibleRegion {
            request.region = region
        }

        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            let results = response.mapItems.map { PlaceResult(mapItem: $0) }
            self.searchResults = results
            saveCachedResults(results, for: query)
        } catch {
            print("MKLocalSearch falló: \(error.localizedDescription)")
            // Si falla la red, intentar caché de nuevo
            if let cached = loadCachedResults(for: query) {
                self.searchResults = cached
            }
        }
    }

    /// Selecciona un PlaceResult y crea un destino con sus coordenadas.
    func selectPlace(_ place: PlaceResult) {
        searchText = ""
        let dest = Destination(
            name: place.name,
            latitude: place.latitude,
            longitude: place.longitude
        )
        updateDestination(dest)
    }

    // MARK: - Cache Offline de Búsquedas

    private let cacheFileName = "search_cache.json"

    private func cacheFileURL() -> URL? {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths.first?.appendingPathComponent(cacheFileName)
    }

    private func saveCachedResults(_ results: [PlaceResult], for query: String) {
        var cache = searchCache
        cache[query] = results
        searchCache = cache
        persistCache(cache)
    }

    private func loadCachedResults(for query: String) -> [PlaceResult]? {
        if let cached = searchCache[query] { return cached }
        // Intentar cargar desde disco
        guard let url = cacheFileURL(),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [PlaceResult]].self, from: data) else {
            return nil
        }
        searchCache = decoded
        return decoded[query]
    }

    private func persistCache(_ cache: [String: [PlaceResult]]) {
        guard let url = cacheFileURL(),
              let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: url)
    }

    // (DESACTIVADO) Carga de paraderos
//    func loadBusStops() { ... }

    // MARK: - (DESACTIVADO) Selección de Rutas y Paradas
//    func selectRoute(_ routeName: String) { ... }
//    func selectStop(_ stop: BusStop) { ... }
//    func handleMapStopSelection(_ stop: BusStop?) { ... }
//    func clearRouteFilter() { ... }

    // MARK: - Public: Map Region

    /// Stores the current visible map region and computes the north–south camera distance.
    ///
    /// - Parameter region: The current `MKCoordinateRegion` from `onMapCameraChange`.
    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        mapVisibleRegion = region
        let north = CLLocation(latitude: region.center.latitude + region.span.latitudeDelta / 2,
                               longitude: region.center.longitude)
        let south = CLLocation(latitude: region.center.latitude - region.span.latitudeDelta / 2,
                               longitude: region.center.longitude)
        mapCameraDistance = north.distance(from: south)
    }

    // MARK: - Public: Sheet Detents

    /// Animates the sheet detent to the default for the current state.
    func updateDetentForCurrentState() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            selectedDetent = defaultDetent
        }
    }

    // MARK: - Public: Destination

    /// Updates the current destination and notifies the location manager.
    ///
    /// - Parameter destination: The new destination.
    func updateDestination(_ destination: Destination) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            tripEngine.updateDestination(destination)
            destinationName = destination.name ?? ""
            fetchETA(for: destination)
            updateDetentForCurrentState()
        }
        let coord = CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
        locationManager.setDestination(coord)
    }

    /// Persiste el nombre editado y actualiza el favorito si ya existe (upsert).
    func confirmDestinationName() {
        let trimmed = destinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Punto Seleccionado" : trimmed
        tripEngine.updateDestinationName(name)

        // Si el destino ya está en favoritos, actualizamos el nombre también
        guard let dest = tripEngine.currentDestination else { return }
        if let index = savedFavorites.firstIndex(where: { $0.latitude == dest.latitude && $0.longitude == dest.longitude }) {
            var updated = savedFavorites[index]
            updated.name = name
            savedFavorites[index] = updated
            preferencesStore.saveFavorites(savedFavorites)
        }
    }

    /// Clears the current destination and resets all related state.
    func clearDestination() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            tripEngine.cancelTrip()
            simulatedETA = nil
            errorMessage = nil
            destinationName = ""
            searchText = ""
            updateDetentForCurrentState()
        }
        locationManager.clearDestination()
        isApproachingStop = false
        distanceToStop = nil
    }

    /// Selects a favorite destination and begins navigation toward it.
    ///
    /// - Parameter dest: The saved favorite to navigate toward.
    func selectFavorite(_ dest: Destination) {
        updateDestination(dest)
    }

    // MARK: - Public: Favorites

    /// Guarda el destino actual como favorito con el ícono dado (upsert por coordenadas).
    ///
    /// - Parameter icon: Nombre de SF Symbol para representar el favorito (ej. `"house.fill"`).
    func saveFavorite(icon: String) {
        guard let dest = tripEngine.currentDestination else { return }
        var saved = dest
        saved.icon = icon
        // Buscamos por coordenadas para evitar duplicados aunque el nombre haya cambiado
        if let index = savedFavorites.firstIndex(where: { $0.latitude == dest.latitude && $0.longitude == dest.longitude }) {
            savedFavorites[index] = saved
        } else {
            savedFavorites.append(saved)
        }
        preferencesStore.saveFavorites(savedFavorites)
    }

    /// Elimina el destino actual de la lista de favoritos (búsqueda por coordenadas).
    func removeFavorite() {
        guard let dest = tripEngine.currentDestination else { return }
        savedFavorites.removeAll { $0.latitude == dest.latitude && $0.longitude == dest.longitude }
        preferencesStore.saveFavorites(savedFavorites)
    }

    /// Indica si el destino actual ya está en favoritos (comparación por coordenadas).
    ///
    /// - Returns: `true` si el destino ya está guardado como favorito.
    func isCurrentDestinationFavorite() -> Bool {
        guard let dest = tripEngine.currentDestination else { return false }
        return savedFavorites.contains { $0.latitude == dest.latitude && $0.longitude == dest.longitude }
    }

    /// Reloads the favorites list from persistent storage.
    func loadFavorites() {
        savedFavorites = preferencesStore.loadFavorites()
    }

    // MARK: - Public: Trip Lifecycle

    /// Activates the trip, transitioning to the `.monitoring` state.
    ///
    /// Checks for appropriate location permissions and shows an error if any are missing.
    func activateTrip() {
        guard let destination = tripEngine.currentDestination else { return }

        if permissionState == .notDetermined {
            locationManager.requestAlwaysAuthorization()
            return
        }

        if permissionState == .denied || permissionState == .restricted {
            errorMessage = "No podemos activar la alarma sin acceso al GPS."
            return
        }

        if permissionState == .authorizedWhenInUse {
            errorMessage = "La alarma requiere permiso 'Siempre' para funcionar en segundo plano."
            return
        }

        AudioManager.shared.prepareAudioEngine()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            tripEngine.startTrip(to: destination, leadTime: leadTime, soundName: ringtoneName)
            isPaused = false
            errorMessage = nil
            updateDetentForCurrentState()
        }
    }

    /// Pauses the active trip.
    func pauseTrip() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isPaused = true
        }
    }

    /// Resumes a paused trip and refreshes the ETA.
    func resumeTrip() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isPaused = false
            if let destination = selectedDestination {
                lastETARequestTime = Date()
                fetchETA(for: destination)
            }
        }
    }

    /// Cancels the trip and clears all trip-related state.
    func cancelTrip() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            tripEngine.cancelTrip()
            simulatedETA = nil
            errorMessage = nil
            isPaused = false
            lastETARequestTime = .distantPast
            updateDetentForCurrentState()
        }
        locationManager.clearDestination()
        isApproachingStop = false
        distanceToStop = nil
    }

    /// Dismisses the finished state. Alias for `cancelTrip()`.
    func dismissFinished() {
        cancelTrip()
    }

    // MARK: - Public: Configuration

    /// Updates the lead time and persists the new value.
    ///
    /// - Parameter newTime: The new lead time.
    func updateLeadTime(_ newTime: AlertLeadTime) {
        self.leadTime = newTime
        preferencesStore.saveLeadTime(newTime)
    }

    /// Updates the app theme instantly — no animation, no cross-fade.
    ///
    /// - Parameter theme: The new theme to apply.
    func updateTheme(_ theme: AppTheme) {
        selectedTheme = theme
        ThemeApplier.apply(theme)
    }

    /// Applies the currently persisted theme to all windows (called on launch).
    func applyPersistedThemeToWindows() {
        ThemeApplier.apply(selectedTheme)
    }

    // MARK: - Public: Scene Phase

    /// Handles `ScenePhase` transitions for energy management.
    ///
    /// Enables eco‑mode (low GPS accuracy) when the app enters the background and
    /// restores normal accuracy on return to foreground.
    ///
    /// - Parameter phase: The new scene phase.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            isAppInBackground = true
            locationManager.enableEcoMode()

        case .active:
            isAppInBackground = false
            locationManager.disableEcoMode()

            if (tripEngine.state == .monitoring || tripEngine.state == .criticalZone),
               let destination = selectedDestination,
               !isPaused {
                lastETARequestTime = Date()
                fetchETA(for: destination)
            }

        default:
            break
        }
    }

    // MARK: - Private Helpers

    /// Normalizes a string for diacritic‑ and case‑insensitive comparison.
    ///
    /// - Parameter string: The raw string.
    /// - Returns: A folded string suitable for comparison.
    private func normalized(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    /// Fetches an ETA estimate from the current location to the given destination.
    ///
    /// - Parameters:
    ///   - destination: The target destination.
    ///   - currentLocation: An optional starting location. Defaults to the user's current location.
    private func fetchETA(for destination: Destination, from currentLocation: CLLocation? = nil) {
        guard !isFetchingETA else { return }
        isFetchingETA = true
        if simulatedETA == nil { isLoadingETA = true }
        errorMessage = nil

        Task {
            do {
                let estimate = try await routeEstimator.estimateRoute(to: destination, from: currentLocation)
                self.simulatedETA = estimate.expectedTravelTime
                self.isLoadingETA = false
                self.isFetchingETA = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoadingETA = false
                self.isFetchingETA = false
            }
        }
    }

    /// Processes an incoming location update from the location manager.
    ///
    /// Updates proximity state (`isApproachingStop`, `distanceToStop`), triggers arrival
    /// at the 100 m threshold, and periodically refreshes the ETA (every 60 s).
    ///
    /// - Parameter location: The latest device location.
    private func processLocationUpdate(_ location: CLLocation) {
        let dest = locationManager.distanceToDestination
        distanceToStop = dest
        isApproachingStop = if let d = dest { d < 500 } else { false }

        if let d = dest, d < 100, tripEngine.state == .monitoring || tripEngine.state == .criticalZone {
            tripEngine.triggerArrival(for: selectedDestination?.name ?? "stop", soundName: ringtoneName)
        }

        guard tripEngine.state == .monitoring || tripEngine.state == .criticalZone,
              let destination = selectedDestination,
              !isPaused else { return }

        guard !isAppInBackground else { return }

        let now = Date()
        if now.timeIntervalSince(lastETARequestTime) >= 60 {
            lastETARequestTime = now
            fetchETA(for: destination)
        }
    }
}

// MARK: - Permission State

extension MapDashboardViewModel {

    /// The current location‑permission state, forwarded from the location manager.
    var permissionState: LocationPermissionState {
        locationManager.permissionState
    }
}

// MARK: - SearchSuggestion

/// Elemento de sugerencia presentado en la lista del sheet inferior.
enum SearchSuggestion: Identifiable {

    /// Un lugar real obtenido de MKLocalSearch.
    case place(PlaceResult)

    /// Un destino favorito guardado por el usuario.
    case favorite(Destination)

    var id: String {
        switch self {
        case .place(let place): return place.id
        case .favorite(let dest): return "fav_\(dest.latitude)_\(dest.longitude)"
        }
    }
}
