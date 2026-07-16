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

@MainActor
@Observable
class MapDashboardViewModel {

    // MARK: - UI State
    var isPaused: Bool = false
    var showSheet: Bool = true
    var showSettings: Bool = false
    var selectedDetent: PresentationDetent = .fraction(0.25)
    var searchText: String = ""

    // MARK: - Bus Stops
    var busStops: [BusStop] = []
    var busStopsLoadError: String? = nil
    var selectedRoute: String? = nil
    var showRouteSearchResults: Bool = false
    var selectedStop: BusStop? = nil

    // MARK: - Adaptive Proximity
    var isApproachingStop: Bool = false
    var distanceToStop: CLLocationDistance? = nil

    // MARK: - Map Region Tracking
    var mapVisibleRegion: MKCoordinateRegion? = nil
    var mapCameraDistance: CLLocationDistance = 0

    private let zoomThresholdMeters: CLLocationDistance = 1_500

    var isZoomedIn: Bool {
        guard let region = mapVisibleRegion else { return false }
        let north = CLLocation(latitude: region.center.latitude + region.span.latitudeDelta / 2,
                               longitude: region.center.longitude)
        let south = CLLocation(latitude: region.center.latitude - region.span.latitudeDelta / 2,
                               longitude: region.center.longitude)
        return north.distance(from: south) < zoomThresholdMeters
    }

    var stopAnnotationScale: CGFloat {
        guard mapCameraDistance > 0 else { return 0.35 }
        let clamped = min(mapCameraDistance, zoomThresholdMeters)
        let t = clamped / zoomThresholdMeters
        return CGFloat(0.35 + (1.0 - t) * 0.65)
    }

    // MARK: - Route Names

    var allRouteNames: [String] {
        let names = busStops.flatMap(\.routeNames)
        return Array(Set(names)).sorted()
    }

    // MARK: - Search Logic (diacritic + case insensitive)

    private func normalized(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    var filteredRouteNames: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let normalizedQuery = normalized(query)
        return allRouteNames.filter { normalized($0).contains(normalizedQuery) }
    }

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

    var visibleBusStops: [BusStop] {
        guard !isZoomedIn, selectedRoute == nil, searchText.isEmpty else {
            return filteredBusStops
        }
        return []
    }

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

    var tripUIState: TripUIState {
        TripUIState.from(engineState: tripEngine.state, isPaused: isPaused)
    }

    var alarmStatus: TripState { tripEngine.state }
    var selectedDestination: Destination? { tripEngine.currentDestination }

    var simulatedETA: TimeInterval? = nil
    var leadTime: AlertLeadTime = .fiveMinutes
    var isLoadingETA: Bool = false
    var errorMessage: String? = nil
    var isOffline: Bool = false
    var destinationName: String = ""
    var savedFavorites: [Destination] = []

    @ObservationIgnored @AppStorage("vibrationEnabled") var vibrationEnabled = true
    var ringtoneName: String = "Alarm" {
        didSet { UserDefaults.standard.set(ringtoneName, forKey: "ringtoneName") }
    }
    var customLeadTimeMinutes = 10 {
        didSet { UserDefaults.standard.set(customLeadTimeMinutes, forKey: "customLeadTime") }
    }

    @ObservationIgnored @AppStorage("appTheme") private var appThemeRaw = AppTheme.liquidGlass.rawValue

    var selectedTheme: AppTheme {
        get { AppTheme(rawValue: appThemeRaw) ?? .liquidGlass }
        set {
            appThemeRaw = newValue.rawValue
            preferencesStore.saveTheme(newValue)
        }
    }

    var currentDetents: Set<PresentationDetent> {
        [.fraction(0.25), .medium, .large]
    }

    var defaultDetent: PresentationDetent {
        switch tripUIState {
        case .initial:     return .fraction(0.25)
        case .configuring: return .medium
        case .active:      return .fraction(0.25)
        case .paused:      return .fraction(0.25)
        case .finished:    return .fraction(0.35)
        }
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

    init(routeEstimator: RouteEstimating? = nil,
         preferencesStore: UserPreferencesStoring? = nil,
         networkMonitor: NetworkMonitoring? = nil,
         locationManager: LocationManaging? = nil,
         tripEngine: TripEngine? = nil) {

        self.routeEstimator = routeEstimator ?? MapKitRouteEstimator()
        self.preferencesStore = preferencesStore ?? UserDefaultsPreferencesStore()
        self.networkMonitor = networkMonitor ?? NetworkMonitor()
        self.locationManager = locationManager ?? AdaptiveLocationManager()
        self.tripEngine = tripEngine ?? TripEngine()

        self.leadTime = self.preferencesStore.loadLeadTime()
        self.ringtoneName = UserDefaults.standard.string(forKey: "ringtoneName") ?? "Alarm"
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

    // MARK: - Bus Stop Loading

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

    // MARK: - Route Search

    func selectRoute(_ routeName: String) {
        selectedRoute = routeName
        searchText = routeName
        showRouteSearchResults = false
    }

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

    func clearRouteFilter() {
        selectedRoute = nil
        searchText = ""
        showRouteSearchResults = false
    }

    // MARK: - Map Region

    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        mapVisibleRegion = region
        let north = CLLocation(latitude: region.center.latitude + region.span.latitudeDelta / 2,
                               longitude: region.center.longitude)
        let south = CLLocation(latitude: region.center.latitude - region.span.latitudeDelta / 2,
                               longitude: region.center.longitude)
        mapCameraDistance = north.distance(from: south)
    }

    // MARK: - Sheet Detent Management

    func updateDetentForCurrentState() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            selectedDetent = defaultDetent
        }
    }

    // MARK: - User Intentions

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

    func confirmDestinationName() {
        let trimmed = destinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Punto Seleccionado" : trimmed
        tripEngine.updateDestinationName(name)
    }

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

    func removeFavorite() {
        guard let dest = tripEngine.currentDestination else { return }
        savedFavorites.removeAll { $0 == dest }
        preferencesStore.saveFavorites(savedFavorites)
    }

    func isCurrentDestinationFavorite() -> Bool {
        guard let dest = tripEngine.currentDestination else { return false }
        return savedFavorites.contains(dest)
    }

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

    func loadFavorites() {
        savedFavorites = preferencesStore.loadFavorites()
    }

    func selectFavorite(_ dest: Destination) {
        updateDestination(dest)
    }

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

    func pauseTrip() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isPaused = true
        }
    }

    func resumeTrip() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isPaused = false
            if let destination = selectedDestination {
                lastETARequestTime = Date()
                fetchETA(for: destination)
            }
        }
    }

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

    func dismissFinished() {
        cancelTrip()
    }

    func updateLeadTime(_ newTime: AlertLeadTime) {
        self.leadTime = newTime
        preferencesStore.saveLeadTime(newTime)
    }

    func updateTheme(_ theme: AppTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTheme = theme
        }
    }

    // MARK: - Private

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

    private func processLocationUpdate(_ location: CLLocation) {
        let dest = locationManager.distanceToDestination
        distanceToStop = dest
        isApproachingStop = if let d = dest { d < 500 } else { false }

        if let d = dest, d < 100, tripEngine.state == .monitoring || tripEngine.state == .criticalZone {
            tripEngine.triggerArrival(for: selectedDestination?.name ?? "stop")
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

    // MARK: - Energy Management

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
}

extension MapDashboardViewModel {
    var permissionState: LocationPermissionState {
        locationManager.permissionState
    }
}

enum SearchSuggestion: Identifiable {
    case route(String)
    case stop(BusStop)
    case favorite(Destination)

    var id: String {
        switch self {
        case .route(let name): return "route_\(name)"
        case .stop(let stop): return "stop_\(stop.id)"
        case .favorite(let dest): return "fav_\(dest.latitude)_\(dest.longitude)"
        }
    }
}
