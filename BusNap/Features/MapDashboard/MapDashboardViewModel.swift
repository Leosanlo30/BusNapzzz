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

/// The central view model for the map dashboard screen.
///
/// ``MapDashboardViewModel`` owns all business logic for:
/// - Loading and filtering bus stops from GeoJSON data.
/// - Tracking the visible map region and computing which stops are on screen.
/// - Managing destination selection, search, favorites, trip lifecycle, and
///   adaptive location-based proximity states.
///
/// The class is annotated with `@MainActor` and `@Observable` so SwiftUI views
/// observe its published properties directly.
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

    // MARK: - Bus Stop Properties

    /// All bus stops loaded from the GeoJSON file.
    var busStops: [BusStop] = []

    /// A localized error description if loading bus stops failed.
    var busStopsLoadError: String? = nil

    /// The route name currently selected as a filter, or `nil` if no route is selected.
    var selectedRoute: String? = nil

    /// Whether the route-search results UI should be visible.
    var showRouteSearchResults: Bool = false

    /// The bus stop the user has tapped on the map or selected from search.
    var selectedStop: BusStop? = nil

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

    /// The raw `@AppStorage` backing for the selected theme.
    @ObservationIgnored @AppStorage("appTheme") private var appThemeRaw = AppTheme.liquidGlass.rawValue

    /// The app's current theme, read from and written to `UserDefaults`.
    var selectedTheme: AppTheme {
        get { AppTheme(rawValue: appThemeRaw) ?? .liquidGlass }
        set {
            appThemeRaw = newValue.rawValue
            preferencesStore.saveTheme(newValue)
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

    /// A dynamic scale factor (0.35…1.0) for bus-stop annotation icons.
    ///
    /// At maximum camera distance (`zoomThresholdMeters`) the scale is 0.35;
    /// at very close distances it approaches 1.0.
    var stopAnnotationScale: CGFloat {
        guard mapCameraDistance > 0 else { return 0.35 }
        let clamped = min(mapCameraDistance, zoomThresholdMeters)
        let t = clamped / zoomThresholdMeters
        return CGFloat(0.35 + (1.0 - t) * 0.65)
    }

    // MARK: - Computed: Route Names

    /// A sorted, de-duplicated list of all route names found across loaded bus stops.
    var allRouteNames: [String] {
        let names = busStops.flatMap(\.routeNames)
        return Array(Set(names)).sorted()
    }

    // MARK: - Computed: Filtered Stops

    /// Route names that match the current `searchText` (diacritic‑ and case‑insensitive).
    var filteredRouteNames: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let normalizedQuery = normalized(query)
        return allRouteNames.filter { normalized($0).contains(normalizedQuery) }
    }

    /// Bus stops that match the current search text and/or selected route filter.
    var filteredBusStops: [BusStop] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = normalized(query)
        var stops = busStops

        if !normalizedQuery.isEmpty {
            stops = stops.filter { stop in
                normalized(stop.name).contains(normalizedQuery)
                || stop.routeNames.contains { normalized($0).contains(normalizedQuery) }
            }
        }

        if let route = selectedRoute {
            stops = stops.filter { $0.routeNames.contains(route) }
        }

        return stops
    }

    /// Bus stops that should be shown on the map.
    ///
    /// Returns an empty array when the map is zoomed out and no search/route filter is active.
    var visibleBusStops: [BusStop] {
        guard !isZoomedIn, selectedRoute == nil, searchText.isEmpty else {
            return filteredBusStops
        }
        return []
    }

    /// Bus stops that are both visible and within the visible map region.
    ///
    /// When the candidate set exceeds 50 stops, a bounding‑box filter clips to the
    /// current `mapVisibleRegion` so the map renders at most ~50 annotations.
    var stopsInSight: [BusStop] {
        let candidates = visibleBusStops
        guard let region = mapVisibleRegion, candidates.count > 50 else {
            return candidates
        }
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLng = region.center.longitude - region.span.longitudeDelta / 2
        let maxLng = region.center.longitude + region.span.longitudeDelta / 2

        return candidates.filter { stop in
            stop.coordinate.latitude >= minLat
            && stop.coordinate.latitude <= maxLat
            && stop.coordinate.longitude >= minLng
            && stop.coordinate.longitude <= maxLng
        }
    }

    // MARK: - Computed: Search Suggestions

    /// An array of search suggestions derived from the current `searchText`.
    ///
    /// Suggestions include up to 8 route matches, 5 stop‑name matches, and 5 favorite
    /// matches, all compared with diacritic‑ and case‑insensitive normalization.
    var searchSuggestions: [SearchSuggestion] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let normalizedQuery = normalized(query)

        let routeMatches = allRouteNames.filter { normalized($0).contains(normalizedQuery) }

        let stopNameMatches: [BusStop]
        if !query.isEmpty {
            stopNameMatches = busStops.filter { normalized($0.name).contains(normalizedQuery) }
        } else {
            stopNameMatches = []
        }

        let favoriteMatches = savedFavorites.filter { fav in
            guard let name = fav.name else { return false }
            return normalized(name).contains(normalizedQuery)
        }

        var suggestions: [SearchSuggestion] = []
        for route in routeMatches.prefix(8) {
            suggestions.append(.route(route))
        }
        for stop in stopNameMatches.prefix(5) {
            suggestions.append(.stop(stop))
        }
        for fav in favoriteMatches.prefix(5) {
            suggestions.append(.favorite(fav))
        }
        return suggestions
    }

    // MARK: - Computed: Route Camera

    /// A map camera position that fits the filtered bus stops with padding.
    ///
    /// Returns `nil` when `filteredBusStops` is empty.
    var routeSearchCamera: MapCameraPosition? {
        let stops = filteredBusStops
        guard !stops.isEmpty else { return nil }
        let coordinates = stops.map(\.coordinate)
        let rect = coordinates.reduce(into: MKMapRect.null) { rect, coord in
            let point = MKMapPoint(coord)
            rect = rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }
        let padded = rect.insetBy(dx: -rect.size.width * 0.3, dy: -rect.size.height * 0.3)
        return .rect(padded)
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
        let storedTheme = self.preferencesStore.loadTheme()
        if storedTheme.rawValue != self.appThemeRaw {
            self.appThemeRaw = storedTheme.rawValue
        }

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

        loadBusStops()
    }

    // MARK: - Public: Bus Stop Loading

    /// Loads bus stops from the `PARADEROS_MERIDA.geojson` bundle resource.
    ///
    /// Sets `busStops` on success or `busStopsLoadError` on failure.
    func loadBusStops() {
        Task {
            do {
                let stops = try GeoJSONManager.shared.loadParaderos(from: "PARADEROS_MERIDA")
                self.busStops = stops
                self.busStopsLoadError = nil
            } catch {
                self.busStopsLoadError = error.localizedDescription
            }
        }
    }

    // MARK: - Public: Route & Stop Selection

    /// Selects a route to filter the map to only its stops.
    ///
    /// - Parameter routeName: The name of the route.
    func selectRoute(_ routeName: String) {
        selectedRoute = routeName
        searchText = routeName
        showRouteSearchResults = false
    }

    /// Selects a bus stop from the search list and creates a destination at its location.
    ///
    /// - Parameter stop: The bus stop to navigate toward.
    func selectStop(_ stop: BusStop) {
        selectedRoute = nil
        searchText = ""
        selectedStop = stop
        let dest = Destination(
            name: stop.name,
            latitude: stop.coordinate.latitude,
            longitude: stop.coordinate.longitude
        )
        updateDestination(dest)
    }

    /// Handles a stop selection initiated from a map tap.
    ///
    /// - Parameter stop: The tapped stop, or `nil` to deselect.
    func handleMapStopSelection(_ stop: BusStop?) {
        selectedStop = stop
        guard let stop else { return }
        let dest = Destination(
            name: stop.name,
            latitude: stop.coordinate.latitude,
            longitude: stop.coordinate.longitude
        )
        updateDestination(dest)
    }

    /// Clears the active route filter and resets search text.
    func clearRouteFilter() {
        selectedRoute = nil
        searchText = ""
        showRouteSearchResults = false
    }

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

    /// Persists the user‑edited destination name back to the trip engine.
    func confirmDestinationName() {
        let trimmed = destinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Punto Seleccionado" : trimmed
        tripEngine.updateDestinationName(name)
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

    /// Saves the current destination as a favorite with the given icon.
    ///
    /// - Parameter icon: An SF Symbol name representing the favorite (e.g. `"house.fill"`).
    func saveFavorite(icon: String) {
        guard let dest = tripEngine.currentDestination else { return }
        var saved = dest
        saved.icon = icon
        if let index = savedFavorites.firstIndex(of: dest) {
            savedFavorites[index] = saved
        } else {
            savedFavorites.append(saved)
        }
        preferencesStore.saveFavorites(savedFavorites)
    }

    /// Removes the current destination from the favorites list.
    func removeFavorite() {
        guard let dest = tripEngine.currentDestination else { return }
        savedFavorites.removeAll { $0 == dest }
        preferencesStore.saveFavorites(savedFavorites)
    }

    /// Returns whether the current destination is already in the favorites list.
    ///
    /// - Returns: `true` if the destination is a saved favorite.
    func isCurrentDestinationFavorite() -> Bool {
        guard let dest = tripEngine.currentDestination else { return false }
        return savedFavorites.contains(dest)
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
            tripEngine.startTrip(to: destination, leadTime: leadTime)
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

    /// Updates the app theme with an animation.
    ///
    /// - Parameter theme: The new theme to apply.
    func updateTheme(_ theme: AppTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTheme = theme
        }
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

/// A search result item presented in the bottom sheet's suggestion list.
enum SearchSuggestion: Identifiable {

    /// A route name match.
    case route(String)

    /// A bus-stop name match.
    case stop(BusStop)

    /// A saved favorite destination match.
    case favorite(Destination)

    var id: String {
        switch self {
        case .route(let name): return "route_\(name)"
        case .stop(let stop): return "stop_\(stop.id)"
        case .favorite(let dest): return "fav_\(dest.latitude)_\(dest.longitude)"
        }
    }
}
