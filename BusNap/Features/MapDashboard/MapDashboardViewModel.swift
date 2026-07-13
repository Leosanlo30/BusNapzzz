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
    
    // MARK: - Estado de la Interfaz (Propiedades)

    var alarmStatus: AlarmStatus = .inactive
    var selectedDestination: Destination? = nil
    var leadTime: AlertLeadTime = .fiveMinutes
    var simulatedETA: Int? = nil

    // MARK: - Configuración de Viaje (persiste entre sesiones)

    var vibrateEnabled: Bool = true {
        didSet { UserDefaults.standard.set(vibrateEnabled, forKey: "vibrateEnabled") }
    }
    var selectedRingtone: String = "Default" {
        didSet { UserDefaults.standard.set(selectedRingtone, forKey: "selectedRingtone") }
    }
    var appTheme: AppTheme = .system {
        didSet { UserDefaults.standard.set(appTheme.rawValue, forKey: "appTheme") }
    }
    var showDebugOverlay: Bool = false
    
    // MARK: - Inicializador (carga configuración guardada)

    init() {
        UserDefaults.standard.register(defaults: [
            "vibrateEnabled": true,
            "selectedRingtone": "Default",
            "appTheme": AppTheme.system.rawValue
        ])
        vibrateEnabled    = UserDefaults.standard.bool(forKey: "vibrateEnabled")
        selectedRingtone  = UserDefaults.standard.string(forKey: "selectedRingtone") ?? "Default"
        appTheme          = AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "") ?? .system

        if let data  = UserDefaults.standard.data(forKey: "leadTime"),
           let saved = try? JSONDecoder().decode(AlertLeadTime.self, from: data) {
            leadTime = saved
        }
    }

    // MARK: - Intenciones (Mutaciones de Estado)
    
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
    
    /// Modifica el tiempo de anticipación para la alarma y lo persiste
    func updateLeadTime(_ time: AlertLeadTime) {
        self.leadTime = time
        if let data = try? JSONEncoder().encode(time) {
            UserDefaults.standard.set(data, forKey: "leadTime")
        }
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
        print("Viaje cancelado. Sistema inactivo.")
    }

    /// Apaga la alarma cuando está sonando y regresa al estado inicial
    func dismissAlarm() {
        alarmStatus = .inactive
        selectedDestination = nil
        simulatedETA = nil
        print("Alarma apagada.")
    }
}
