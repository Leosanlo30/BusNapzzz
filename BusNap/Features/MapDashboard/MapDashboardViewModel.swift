//
//  MapDashboardViewModel.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 08/07/26.
//

import Foundation
import SwiftUI 
import Observation

@MainActor
@Observable
class MapDashboardViewModel {
    
    // MARK: - Estado de la UI
    // Ahora leemos el estado directamente desde el motor de viaje (TripEngine)
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
        
        // Configuración del monitor de red
        self.networkMonitor.setStatusHandler { [weak self] offline in
            guard let self = self else { return }
            Task { @MainActor in
                self.isOffline = offline
            }
        }
        self.networkMonitor.start()
    }
    
    // MARK: - Intenciones (Acciones del Usuario)
    
    func updateDestination(_ destination: Destination) {
        // Redirigimos la gestión del destino al motor
        tripEngine.updateDestination(destination)
        fetchETA(for: destination)
    }
    
    func activateTrip() {
        print("🚨 [ALERTA] ¡Alguien llamó a activateTrip!")
        guard let destination = tripEngine.currentDestination else { return }
        
        // 1. Validar permisos antes de arrancar
        if permissionState == .notDetermined {
            // NUEVO: Pedimos el permiso "Siempre" para que la geocerca despierte la app
            locationManager.requestAlwaysAuthorization()
            return
        }
        
        if permissionState == .denied || permissionState == .restricted {
            errorMessage = "No podemos activar la alarma sin acceso al GPS."
            return
        }
        
        AudioManager.shared.prepareAudioEngine()
        
        // 2. Si todo es correcto, disparamos el motor
        tripEngine.startTrip(to: destination)
        errorMessage = nil
    }
    
    func cancelTrip() {
        // Purga de recursos en el motor
        tripEngine.cancelTrip()
        simulatedETA = nil
        errorMessage = nil
    }
    
    func updateLeadTime(_ newTime: AlertLeadTime) {
            self.leadTime = newTime
            preferencesStore.saveLeadTime(newTime)
        }
    
    // MARK: - Lógica Privada
    private func fetchETA(for destination: Destination) {
        isLoadingETA = true
        errorMessage = nil
        simulatedETA = nil
        
        Task {
            do {
                let estimate = try await routeEstimator.estimateRoute(to: destination)
                self.simulatedETA = estimate.expectedTravelTime
                self.isLoadingETA = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoadingETA = false
            }
        }
    }
    
    // MARK: - Gestión de Energía del Sistema
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // El usuario bloqueó la pantalla o guardó el celular
            locationManager.enableEcoMode()
            
        case .active:
            // El usuario está viendo la pantalla
            locationManager.disableEcoMode()
            
        default:
            break
        }
    }
}
