//
//  MapDashboardViewModel.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 08/07/26.
//

import Foundation
import SwiftUI
import Observation
import CoreLocation // Necesario para recibir CLLocation
import MapKit

@MainActor
@Observable
class MapDashboardViewModel {
    
    // MARK: - Estado de la UI
    var alarmStatus: TripState { tripEngine.state }
    var selectedDestination: Destination? { tripEngine.currentDestination }
    
    var simulatedETA: TimeInterval? = nil
    var leadTime: AlertLeadTime = .fiveMinutes
    var isLoadingETA: Bool = false
    var errorMessage: String? = nil
    var isOffline: Bool = false
    
    // Propiedad computada puente para el estado de permisos
    var permissionState: LocationPermissionState {
        locationManager.permissionState
    }
    
    // MARK: - Dependencias
    @ObservationIgnored private let routeEstimator: RouteEstimating
    @ObservationIgnored private let preferencesStore: UserPreferencesStoring
    @ObservationIgnored private let networkMonitor: NetworkMonitoring
    @ObservationIgnored private let locationManager: LocationManaging
    @ObservationIgnored private let tripEngine: TripEngine
    
    // MARK: - Variables de Control de Energía
    @ObservationIgnored private var lastETARequestTime: Date = .distantPast
    @ObservationIgnored private var isAppInBackground: Bool = false
    @ObservationIgnored private var isFetchingETA: Bool = false
    
    // Inicializador completo con inyección de dependencias
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
        
        // 1. Configuración del monitor de red
        self.networkMonitor.setStatusHandler { [weak self] offline in
            guard let self = self else { return }
            Task { @MainActor in
                self.isOffline = offline
            }
        }
        self.networkMonitor.start()
        
        // 2. CONECTAMOS EL CABLE DEL GPS AL VIEWMODEL
        self.locationManager.setLocationHandler { [weak self] newLocation in
            guard let self = self else { return }
            Task { @MainActor in
                self.processLocationUpdate(newLocation)
            }
        }
    }
    
    // MARK: - Intenciones (Acciones del Usuario)
    
    func updateDestination(_ destination: Destination) {
        tripEngine.updateDestination(destination)
        fetchETA(for: destination)
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
            errorMessage = "La alarma requiere permiso 'Siempre' para funcionar en segundo plano. Ve a Configuración > Privacidad > Localización."
            return
        }
        
        AudioManager.shared.prepareAudioEngine()
        tripEngine.startTrip(to: destination, leadTime: leadTime)
        errorMessage = nil
    }
    
    func cancelTrip() {
        tripEngine.cancelTrip()
        simulatedETA = nil
        errorMessage = nil
        lastETARequestTime = .distantPast // Reiniciamos el cronómetro interno
    }
    
    func updateLeadTime(_ newTime: AlertLeadTime) {
        self.leadTime = newTime
        preferencesStore.saveLeadTime(newTime)
    }
    
    // MARK: - Lógica Privada
    
    // MARK: - Lógica Privada
        
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
        // Solo pedimos el ETA nuevo si estamos en viaje y con destino
        guard alarmStatus == .monitoring, let destination = selectedDestination else { return }
        
        // EL FRENO DE MANO: Abortamos si la app está en el bolsillo
        guard !isAppInBackground else { return }
        
        let now = Date()
        
        //Intervalo de debug
        if now.timeIntervalSince(lastETARequestTime) >= 60 {
            lastETARequestTime = now
            print("🔄 [UI] Han pasado 60s. Pidiendo nuevo ETA a Apple Maps...")
            fetchETA(for: destination)
        }
    }
    
    // MARK: - Gestión de Energía del Sistema
    
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            isAppInBackground = true
            locationManager.enableEcoMode()
            print("🌙 [ENERGÍA] Pantalla apagada: UI y peticiones de ETA pausadas.")
            
        case .active:
            isAppInBackground = false
            locationManager.disableEcoMode()
            print("☀️ [ENERGÍA] Pantalla encendida: Retomando UI.")
            
            // Forzamos una actualización inmediata al abrir la app
            if alarmStatus == .monitoring, let destination = selectedDestination {
                lastETARequestTime = Date()
                fetchETA(for: destination)
            }
            
        default:
            break
        }
    }
}
