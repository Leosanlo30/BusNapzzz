//
//  MapDashboardViewModel.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 08/07/26.
//

import OSLog
import Foundation
import SwiftUI
import Observation
import CoreLocation
import MapKit

// MARK: - MapDashboardViewModel

/// ViewModel central de la pantalla del mapa.
///
/// Coordina la búsqueda de lugares, los favoritos y recientes, el ciclo de vida
/// del viaje (delegado en ``TripEngine``) y el GPS adaptativo.
@MainActor
@Observable
final class MapDashboardViewModel {

    // MARK: - UI State

    /// Whether the trip timer is in a paused state (pausa la actualización del ETA).
    var isPaused: Bool = false

    /// Whether the bottom sheet is presented.
    var showSheet: Bool = true

    /// Whether the settings full-screen cover is presented.
    var showSettings: Bool = false

    /// The currently selected presentation detent for the bottom sheet.
    var selectedDetent: PresentationDetent = MapDashboardViewModel.compactDetent

    /// The text currently entered in the search bar.
    var searchText: String = "" {
        didSet {
            guard searchText != oldValue else { return }
            searchResults = []
            placeSearch.updateQuery(searchText, region: mapVisibleRegion)
        }
    }

    /// Resultados de la última búsqueda completa (al pulsar "Buscar").
    var searchResults: [PlaceResult] = []

    /// Whether a full search or suggestion resolution is in flight.
    var isSearching: Bool = false

    // MARK: - Proximity

    /// Whether the user is within 500 m of the destination.
    var isApproachingStop: Bool = false

    /// The current distance from the user to the destination, in meters.
    var distanceToStop: CLLocationDistance? = nil

    // MARK: - Map

    /// The last known visible region of the map.
    var mapVisibleRegion: MKCoordinateRegion? = nil

    /// Geometría de la ruta estimada hacia el destino.
    var routePath: [RouteCoordinate] = []

    // MARK: - Trip & Destination

    var tripUIState: TripUIState {
        TripUIState.from(engineState: tripEngine.state, isPaused: isPaused)
    }

    var alarmStatus: TripState { tripEngine.state }

    var selectedDestination: Destination? { tripEngine.currentDestination }

    var isTripActive: Bool { tripEngine.isMonitoring }

    /// The estimated travel time from the current location to the destination, in seconds.
    var simulatedETA: TimeInterval? = nil

    /// Distancia de la ruta estimada, en metros.
    var routeDistance: CLLocationDistance? = nil

    /// Momento en que se calculó `simulatedETA`, para mostrar la hora de llegada.
    var etaUpdatedAt: Date? = nil

    /// The user's configured lead time for the arrival alarm.
    var leadTime: AlertLeadTime = .fiveMinutes

    var isLoadingETA: Bool = false

    /// A user-facing error message, or `nil`.
    var errorMessage: String? = nil

    /// Si el error se resuelve abriendo la app Ajustes (permisos).
    var errorNeedsSettings: Bool = false

    var isOffline: Bool = false

    /// The user-editable display name for the current destination.
    var destinationName: String = ""

    var savedFavorites: [Destination] = []

    /// Últimos destinos a los que el usuario inició un viaje.
    var recentDestinations: [Destination] = []

    var notificationPermission: NotificationPermission = .notDetermined

    /// Preferencias del usuario (alarma y mapa).
    let settings: AppSettings

    /// Altura compacta: barra de búsqueda + favoritos, o el resumen del viaje.
    static let compactDetent: PresentationDetent = .fraction(0.32)

    var currentDetents: Set<PresentationDetent> {
        [Self.compactDetent, .medium, .large]
    }

    var defaultDetent: PresentationDetent {
        switch tripUIState {
        case .initial:     return Self.compactDetent
        case .configuring: return .medium
        case .active:      return Self.compactDetent
        case .paused:      return Self.compactDetent
        case .finished:    return .medium
        }
    }

    /// Radio de la zona de alarma para el tiempo de aviso actual.
    var alarmRadius: CLLocationDistance {
        TripEngine.alarmRadius(forLeadTimeMinutes: leadTime.minutes)
    }

    /// Hora estimada de llegada.
    var estimatedArrival: Date? {
        guard let eta = simulatedETA, let updatedAt = etaUpdatedAt else { return nil }
        return updatedAt.addingTimeInterval(eta)
    }

    // MARK: - Search Suggestions

    /// Sugerencias combinando favoritos, resultados de búsqueda y autocompletado.
    var searchSuggestions: [SearchSuggestion] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        let favoriteMatches = savedFavorites
            .filter { $0.name?.localizedStandardContains(query) ?? false }
            .prefix(3)
            .map(SearchSuggestion.favorite)

        let remote: [SearchSuggestion] = searchResults.isEmpty
            ? placeSearch.suggestions.map(SearchSuggestion.completion)
            : searchResults.prefix(10).map(SearchSuggestion.place)

        return favoriteMatches + remote
    }

    // MARK: - Dependencies

    @ObservationIgnored private let routeEstimator: RouteEstimating
    @ObservationIgnored private let preferencesStore: UserPreferencesStoring
    @ObservationIgnored private let networkMonitor: NetworkMonitoring
    @ObservationIgnored private let locationManager: LocationManaging
    @ObservationIgnored private let tripEngine: TripEngine
    @ObservationIgnored private let placeSearch: PlaceSearching

    @ObservationIgnored private var etaTask: Task<Void, Never>?
    @ObservationIgnored private var lastETARequestTime: Date = .distantPast
    @ObservationIgnored private var isAppInBackground: Bool = false
    /// El usuario pulsó "Iniciar viaje" y esperamos a que conceda el permiso.
    @ObservationIgnored private var pendingActivation: Bool = false

    /// Distancia a la que el GPS dispara la alarma si la geocerca no lo hizo antes.
    private let arrivalThreshold: CLLocationDistance = 100
    private let etaRefreshInterval: TimeInterval = 60
    private let maxRecents = 8

    // MARK: - Initialization

    init(
        routeEstimator: RouteEstimating? = nil,
        preferencesStore: UserPreferencesStoring? = nil,
        networkMonitor: NetworkMonitoring? = nil,
        locationManager: LocationManaging? = nil,
        tripEngine: TripEngine? = nil,
        placeSearch: PlaceSearching? = nil,
        settings: AppSettings? = nil
    ) {
        self.routeEstimator = routeEstimator ?? MapKitRouteEstimator()
        self.preferencesStore = preferencesStore ?? UserDefaultsPreferencesStore()
        self.networkMonitor = networkMonitor ?? NetworkMonitor()
        self.locationManager = locationManager ?? AdaptiveLocationManager()
        self.tripEngine = tripEngine ?? TripEngine()
        self.placeSearch = placeSearch ?? PlaceSearchService()
        self.settings = settings ?? AppSettings()

        leadTime = self.preferencesStore.loadLeadTime()
        savedFavorites = self.preferencesStore.loadFavorites()
        recentDestinations = self.preferencesStore.loadRecents()

        self.networkMonitor.setStatusHandler { [weak self] offline in
            Task { @MainActor [weak self] in self?.isOffline = offline }
        }
        self.networkMonitor.start()

        self.locationManager.setLocationHandler { [weak self] location in
            self?.processLocationUpdate(location)
        }
        self.locationManager.setAuthorizationHandler { [weak self] state in
            self?.handleAuthorizationChange(state)
        }
        self.tripEngine.onAlarmTriggered = { [weak self] in
            self?.handleAlarmTriggered()
        }

        // iOS pudo relanzar la app con un viaje en curso: reanudamos el GPS.
        if self.tripEngine.isMonitoring, let destination = self.tripEngine.currentDestination {
            destinationName = destination.name ?? ""
            selectedDetent = defaultDetent
            self.locationManager.startTracking(to: destination.coordinate)
        }
    }

    // MARK: - Lifecycle

    /// Llamar al mostrar la pantalla. Pide permiso de ubicación "Al usar" para
    /// mostrar el punto azul; "Siempre" se pide al iniciar el primer viaje.
    func onAppear() {
        if permissionState == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        refreshNotificationPermission()
    }

    // MARK: - Search

    /// Búsqueda completa con el texto actual (al pulsar "Buscar" en el teclado).
    func performLocalSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isSearching = true
        defer { isSearching = false }
        do {
            let results = try await placeSearch.search(query, region: mapVisibleRegion)
            // Si el usuario siguió escribiendo, estos resultados ya no aplican.
            guard query == searchText.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            searchResults = results
        } catch {
            Log.search.error("Búsqueda falló: \(error.localizedDescription, privacy: .public)")
        }
    }

    func clearSearch() {
        searchText = ""
        searchResults = []
    }

    func selectSuggestion(_ suggestion: SearchSuggestion) async {
        switch suggestion {
        case .place(let place):
            selectPlace(place)
        case .favorite(let destination):
            clearSearch()
            updateDestination(destination)
        case .completion(let completion):
            isSearching = true
            defer { isSearching = false }
            do {
                if let place = try await placeSearch.resolve(completion) {
                    selectPlace(place)
                }
            } catch {
                errorMessage = "No pudimos abrir ese lugar. Revisa tu conexión."
                errorNeedsSettings = false
            }
        }
    }

    /// Selecciona un PlaceResult y crea un destino con sus coordenadas.
    func selectPlace(_ place: PlaceResult) {
        clearSearch()
        updateDestination(Destination(name: place.name, latitude: place.latitude, longitude: place.longitude))
    }

    // MARK: - Map Interaction

    /// Tocar el mapa coloca un destino; durante un viaje se ignora para no
    /// cancelarlo por accidente.
    func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        guard !isTripActive, tripUIState != .finished else { return }
        let placeholder = "Punto seleccionado"
        let destination = Destination(name: placeholder, latitude: coordinate.latitude, longitude: coordinate.longitude)
        updateDestination(destination)

        // Nombre real del lugar, sin pisar lo que el usuario ya haya escrito.
        Task {
            guard let name = await placeSearch.name(for: coordinate),
                  selectedDestination == destination,
                  destinationName == placeholder else { return }
            destinationName = name
            tripEngine.updateDestinationName(name)
        }
    }

    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        mapVisibleRegion = region
    }

    // MARK: - Sheet Detents

    func updateDetentForCurrentState() {
        withAnimation(.busnapSpring) {
            selectedDetent = defaultDetent
        }
    }

    // MARK: - Destination

    func updateDestination(_ destination: Destination) {
        let wasTracking = isTripActive
        etaTask?.cancel()
        withAnimation(.busnapSpring) {
            tripEngine.updateDestination(destination)
            destinationName = destination.name ?? ""
            simulatedETA = nil
            routeDistance = nil
            routePath = []
            errorMessage = nil
            fetchETA(for: destination)
            updateDetentForCurrentState()
        }
        if wasTracking { stopTracking() }
    }

    /// Persiste el nombre editado y actualiza el favorito si ya existe (upsert).
    func confirmDestinationName() {
        let trimmed = destinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Punto seleccionado" : trimmed
        tripEngine.updateDestinationName(name)

        guard let dest = tripEngine.currentDestination,
              let index = savedFavorites.firstIndex(where: { $0.isSamePlace(as: dest) }) else { return }
        savedFavorites[index].name = name
        preferencesStore.saveFavorites(savedFavorites)
    }

    func clearDestination() {
        resetTrip()
        withAnimation(.busnapSpring) {
            destinationName = ""
            searchText = ""
            updateDetentForCurrentState()
        }
    }

    func selectFavorite(_ dest: Destination) {
        updateDestination(dest)
    }

    // MARK: - Favorites & Recents

    /// Guarda el destino actual como favorito con el ícono dado (upsert por ubicación).
    func saveFavorite(icon: String) {
        guard var saved = tripEngine.currentDestination else { return }
        saved.icon = icon
        if let index = savedFavorites.firstIndex(where: { $0.isSamePlace(as: saved) }) {
            savedFavorites[index] = saved
        } else {
            savedFavorites.append(saved)
        }
        preferencesStore.saveFavorites(savedFavorites)
    }

    func removeFavorite() {
        guard let dest = tripEngine.currentDestination else { return }
        removeFavorite(dest)
    }

    func removeFavorite(_ favorite: Destination) {
        savedFavorites.removeAll { $0.isSamePlace(as: favorite) }
        preferencesStore.saveFavorites(savedFavorites)
    }

    func isCurrentDestinationFavorite() -> Bool {
        guard let dest = tripEngine.currentDestination else { return false }
        return savedFavorites.contains { $0.isSamePlace(as: dest) }
    }

    func loadFavorites() {
        savedFavorites = preferencesStore.loadFavorites()
    }

    func removeRecent(_ recent: Destination) {
        recentDestinations.removeAll { $0.isSamePlace(as: recent) }
        preferencesStore.saveRecents(recentDestinations)
    }

    func clearRecents() {
        recentDestinations = []
        preferencesStore.saveRecents([])
    }

    private func addRecent(_ destination: Destination) {
        var recents = recentDestinations.filter { !$0.isSamePlace(as: destination) }
        recents.insert(destination, at: 0)
        recentDestinations = Array(recents.prefix(maxRecents))
        preferencesStore.saveRecents(recentDestinations)
    }

    // MARK: - Trip Lifecycle

    /// Inicia el viaje si hay permiso de ubicación "Siempre"; si no, lo pide
    /// y el viaje arranca solo cuando el usuario lo concede.
    func activateTrip() {
        guard tripEngine.currentDestination != nil else { return }

        switch permissionState {
        case .notDetermined:
            pendingActivation = true
            locationManager.requestAlwaysAuthorization()
            return

        case .denied, .restricted:
            showError("No podemos activar la alarma sin acceso al GPS.", needsSettings: true)
            return

        case .authorizedWhenInUse:
            pendingActivation = true
            locationManager.requestAlwaysAuthorization()
            showError("La alarma requiere permiso 'Siempre' para funcionar en segundo plano.", needsSettings: true)
            return

        case .authorizedAlways:
            startTrip()
        }
    }

    private func startTrip() {
        guard let destination = tripEngine.currentDestination else { return }
        pendingActivation = false

        withAnimation(.busnapSpring) {
            tripEngine.startTrip(
                to: destination,
                leadTime: leadTime,
                soundName: settings.ringtoneName,
                vibrate: settings.vibrationEnabled
            )
            isPaused = false
            errorMessage = nil
            updateDetentForCurrentState()
        }
        locationManager.startTracking(to: destination.coordinate)
        addRecent(destination)

        Task {
            notificationPermission = await tripEngine.requestNotificationPermissionIfNeeded()
        }
    }

    func pauseTrip() {
        withAnimation(.busnapSpring) {
            isPaused = true
        }
    }

    func resumeTrip() {
        withAnimation(.busnapSpring) {
            isPaused = false
        }
        if let destination = selectedDestination {
            lastETARequestTime = Date()
            fetchETA(for: destination)
        }
    }

    func cancelTrip() {
        resetTrip()
        withAnimation(.busnapSpring) {
            updateDetentForCurrentState()
        }
    }

    /// Botón "Detener alarma": apaga sonido y vibración y vuelve al inicio.
    func dismissFinished() {
        cancelTrip()
    }

    // MARK: - Configuration

    func updateLeadTime(_ newTime: AlertLeadTime) {
        leadTime = newTime
        preferencesStore.saveLeadTime(newTime)
    }

    // MARK: - Scene Phase

    /// Modo ahorro en segundo plano y refresco al volver a primer plano.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            isAppInBackground = true
            locationManager.enableEcoMode()

        case .active:
            isAppInBackground = false
            locationManager.disableEcoMode()
            refreshNotificationPermission()

            if isTripActive, let destination = selectedDestination, !isPaused {
                lastETARequestTime = Date()
                fetchETA(for: destination)
            }

        default:
            break
        }
    }

    // MARK: - Private

    private func showError(_ message: String, needsSettings: Bool) {
        errorMessage = message
        errorNeedsSettings = needsSettings
    }

    private func refreshNotificationPermission() {
        Task {
            notificationPermission = await tripEngine.notificationPermissionStatus()
        }
    }

    private func stopTracking() {
        locationManager.stopTracking()
        isApproachingStop = false
        distanceToStop = nil
    }

    /// Estado común de cancelar el viaje o quitar el destino.
    private func resetTrip() {
        etaTask?.cancel()
        etaTask = nil
        pendingActivation = false
        withAnimation(.busnapSpring) {
            tripEngine.cancelTrip()
            simulatedETA = nil
            routeDistance = nil
            etaUpdatedAt = nil
            routePath = []
            isLoadingETA = false
            errorMessage = nil
            isPaused = false
        }
        lastETARequestTime = .distantPast
        stopTracking()
    }

    private func handleAuthorizationChange(_ state: LocationPermissionState) {
        guard pendingActivation else { return }
        switch state {
        case .authorizedAlways:
            errorMessage = nil
            startTrip()
        case .denied, .restricted:
            pendingActivation = false
            showError("No podemos activar la alarma sin acceso al GPS.", needsSettings: true)
        case .authorizedWhenInUse:
            showError("La alarma requiere permiso 'Siempre' para funcionar en segundo plano.", needsSettings: true)
        case .notDetermined:
            break
        }
    }

    private func handleAlarmTriggered() {
        etaTask?.cancel()
        stopTracking()
        updateDetentForCurrentState()
    }

    /// Estima la ruta hacia el destino. Una petición nueva cancela la anterior,
    /// así nunca se muestra el ETA de un destino previo.
    private func fetchETA(for destination: Destination, from currentLocation: CLLocation? = nil) {
        etaTask?.cancel()
        if simulatedETA == nil { isLoadingETA = true }

        etaTask = Task {
            defer { if !Task.isCancelled { isLoadingETA = false } }
            do {
                let estimate = try await routeEstimator.estimateRoute(to: destination, from: currentLocation)
                try Task.checkCancellation()
                simulatedETA = estimate.expectedTravelTime
                routeDistance = estimate.distance
                etaUpdatedAt = .now
                if !estimate.path.isEmpty { routePath = estimate.path }
                if errorMessage != nil, !errorNeedsSettings { errorMessage = nil }
            } catch is CancellationError {
                // Reemplazada por una petición más reciente.
            } catch {
                guard !Task.isCancelled else { return }
                showError(error.localizedDescription, needsSettings: false)
            }
        }
    }

    /// Actualiza la proximidad, dispara la llegada a 100 m y refresca el ETA cada 60 s.
    private func processLocationUpdate(_ location: CLLocation) {
        let distance = locationManager.distanceToDestination
        distanceToStop = distance
        isApproachingStop = distance.map { $0 < 500 } ?? false

        guard isTripActive else { return }

        if let distance, distance < arrivalThreshold {
            tripEngine.triggerArrival()
            return
        }

        guard !isPaused, !isAppInBackground, let destination = selectedDestination else { return }

        let now = Date()
        if now.timeIntervalSince(lastETARequestTime) >= etaRefreshInterval {
            lastETARequestTime = now
            fetchETA(for: destination, from: location)
        }
    }
}

// MARK: - Permission State

extension MapDashboardViewModel {

    var permissionState: LocationPermissionState {
        locationManager.permissionState
    }
}

// MARK: - SearchSuggestion

/// Elemento de sugerencia presentado en la lista del sheet inferior.
enum SearchSuggestion: Identifiable {

    /// Sugerencia de autocompletado mientras se escribe.
    case completion(PlaceSuggestion)

    /// Un lugar real obtenido de MKLocalSearch.
    case place(PlaceResult)

    /// Un destino favorito guardado por el usuario.
    case favorite(Destination)

    var id: String {
        switch self {
        case .completion(let suggestion): return "cmp_\(suggestion.id)"
        case .place(let place): return place.id
        case .favorite(let dest): return "fav_\(dest.latitude)_\(dest.longitude)"
        }
    }
}
