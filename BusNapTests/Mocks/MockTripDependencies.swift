//
//  MockTripDependencies.swift
//  BusNapTests
//

import Foundation
import CoreLocation
import MapKit
@testable import BusNap

@MainActor
final class MockGeofenceMonitor: GeofenceMonitoring {
    var onRegionEntered: ((String) -> Void)?
    private(set) var monitoredIdentifier: String?
    private(set) var monitoredRadius: CLLocationDistance?
    private(set) var stopCount = 0

    func startMonitoring(destination: Destination, radius: CLLocationDistance, identifier: String) {
        monitoredIdentifier = identifier
        monitoredRadius = radius
    }

    func stopMonitoring() {
        monitoredIdentifier = nil
        stopCount += 1
    }

    /// Simula que el sistema operativo avisa de la entrada en la región.
    func simulateEntry(identifier: String? = nil) {
        guard let id = identifier ?? monitoredIdentifier else { return }
        onRegionEntered?(id)
    }
}

final class MockNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    var status: NotificationPermission = .notDetermined
    var grantOnRequest = true
    private(set) var requestCount = 0
    private(set) var scheduledCount = 0

    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        status = grantOnRequest ? .authorized : .denied
        return grantOnRequest
    }

    func authorizationStatus() async -> NotificationPermission { status }

    func scheduleWakeUpAlarm(title: String, body: String, soundName: String) async throws {
        scheduledCount += 1
    }

    func cancelPendingAlarms() {}
}

@MainActor
final class MockAlarmPlayer: AlarmPlaying {
    private(set) var playCount = 0
    private(set) var lastVibrate: Bool?
    private(set) var lastSound: String?
    private(set) var isPlaying = false

    func prepare() {}

    func playAlarm(soundName: String, vibrate: Bool) {
        playCount += 1
        lastSound = soundName
        lastVibrate = vibrate
        isPlaying = true
    }

    func stopAlarm() {
        isPlaying = false
    }
}

final class InMemoryActiveTripStore: ActiveTripStoring {
    var trip: ActiveTrip?

    init(trip: ActiveTrip? = nil) {
        self.trip = trip
    }

    func load() -> ActiveTrip? { trip }
    func save(_ trip: ActiveTrip) { self.trip = trip }
    func clear() { trip = nil }
}

@MainActor
final class MockPlaceSearch: PlaceSearching {
    var suggestions: [PlaceSuggestion] = []
    var results: [PlaceResult] = []

    func updateQuery(_ query: String, region: MKCoordinateRegion?) {}
    func search(_ query: String, region: MKCoordinateRegion?) async throws -> [PlaceResult] { results }
    func resolve(_ suggestion: PlaceSuggestion) async throws -> PlaceResult? { nil }
    func name(for coordinate: CLLocationCoordinate2D) async -> String? { nil }
}

final class MockPreferencesStore: UserPreferencesStoring, @unchecked Sendable {
    var memoryStorage: AlertLeadTime = .fiveMinutes
    var favoriteStorage: [Destination] = []
    var recentStorage: [Destination] = []

    func saveLeadTime(_ time: AlertLeadTime) { memoryStorage = time }
    func loadLeadTime() -> AlertLeadTime { memoryStorage }
    func saveFavorites(_ favorites: [Destination]) { favoriteStorage = favorites }
    func loadFavorites() -> [Destination] { favoriteStorage }
    func saveRecents(_ recents: [Destination]) { recentStorage = recents }
    func loadRecents() -> [Destination] { recentStorage }
}

// MARK: - Factory

/// Construye objetos bajo prueba sin tocar hardware, UserDefaults reales ni audio.
@MainActor
struct TestEnvironment {
    let location: MockLocationManager
    let geofence = MockGeofenceMonitor()
    let notifications = MockNotificationScheduler()
    let alarm = MockAlarmPlayer()
    let tripStore: InMemoryActiveTripStore
    let preferences = MockPreferencesStore()
    let network = MockNetworkMonitor()
    let search = MockPlaceSearch()
    let settings = AppSettings(defaults: UserDefaults(suiteName: "BusNapTests.\(UUID().uuidString)")!)

    init(permission: LocationPermissionState = .authorizedAlways, storedTrip: ActiveTrip? = nil) {
        location = MockLocationManager(initialState: permission)
        tripStore = InMemoryActiveTripStore(trip: storedTrip)
    }

    func makeEngine() -> TripEngine {
        TripEngine(geofenceMonitor: geofence, notificationManager: notifications,
                   alarmPlayer: alarm, store: tripStore)
    }

    func makeViewModel(routeEstimator: MockRouteEstimator = MockRouteEstimator()) -> MapDashboardViewModel {
        MapDashboardViewModel(
            routeEstimator: routeEstimator,
            preferencesStore: preferences,
            networkMonitor: network,
            locationManager: location,
            tripEngine: makeEngine(),
            placeSearch: search,
            settings: settings
        )
    }
}

/// Espera activa hasta que se cumpla la condición (evita `sleep` fijos frágiles).
@MainActor
func waitUntil(timeout: Duration = .seconds(2), _ condition: @MainActor () -> Bool) async {
    let deadline = ContinuousClock.now + timeout
    while !condition() && ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(10))
    }
}
