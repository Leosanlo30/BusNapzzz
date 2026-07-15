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
    var showSettings: Bool = false
    var showSheet: Bool = true
    var selectedDetent: PresentationDetent = .fraction(0.2)
    var searchText: String = ""

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

    var vibrationEnabled: Bool = true {
        didSet { UserDefaults.standard.set(vibrationEnabled, forKey: "vibrationEnabled") }
    }
    var ringtoneName: String = "Alarm" {
        didSet { UserDefaults.standard.set(ringtoneName, forKey: "ringtoneName") }
    }
    var customLeadTimeMinutes: Int = 10 {
        didSet { UserDefaults.standard.set(customLeadTimeMinutes, forKey: "customLeadTimeMinutes") }
    }

    var selectedTheme: AppTheme = .liquidGlass {
        didSet { preferencesStore.saveTheme(selectedTheme) }
    }

    var currentDetents: Set<PresentationDetent> {
        [.fraction(0.2), .medium, .large]
    }

    var defaultDetent: PresentationDetent {
        switch tripUIState {
        case .initial:     return .fraction(0.2)
        case .configuring: return .medium
        case .active:      return .fraction(0.2)
        case .paused:      return .fraction(0.2)
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
        self.locationManager = locationManager ?? LocationManager()
        self.tripEngine = tripEngine ?? TripEngine()

        self.leadTime = self.preferencesStore.loadLeadTime()
        self.selectedTheme = self.preferencesStore.loadTheme()
        self.vibrationEnabled = UserDefaults.standard.bool(forKey: "vibrationEnabled")
        self.ringtoneName = UserDefaults.standard.string(forKey: "ringtoneName") ?? "Alarm"
        self.customLeadTimeMinutes = UserDefaults.standard.integer(forKey: "customLeadTimeMinutes")
        if self.customLeadTimeMinutes == 0 { self.customLeadTimeMinutes = 10 }

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
    }

    func confirmDestinationName() {
        let trimmed = destinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Punto Seleccionado" : trimmed
        tripEngine.updateDestinationName(name)
    }

    func toggleFavorite() {
        guard let dest = tripEngine.currentDestination else { return }
        if let index = savedFavorites.firstIndex(of: dest) {
            savedFavorites.remove(at: index)
        } else {
            savedFavorites.append(dest)
        }
        preferencesStore.saveFavorites(savedFavorites)
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
