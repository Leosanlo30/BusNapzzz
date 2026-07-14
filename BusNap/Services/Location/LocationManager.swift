//
//  LocationManager.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class LocationManager: NSObject, LocationManaging {
    
    // MARK: - Estado Expuesto
    // Usamos private(set) para que las vistas puedan leer el estado, pero solo esta clase pueda mutarlo
    private(set) var permissionState: LocationPermissionState = .notDetermined
    
    // MARK: - Dependencias Internas
    @ObservationIgnored private let clManager = CLLocationManager()
    @ObservationIgnored private var locationHandler: ((CLLocation) -> Void)? //guardará la función a ejecutar cuando haya movimiento
    
    override init() {
        super.init()
        
        // 1. Nos auto-asignamos como el delegado para escuchar al hardware
        self.clManager.delegate = self
        
        // --- OPTIMIZACIONES DE ENERGÍA ---
        self.clManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        self.clManager.distanceFilter = 50
        self.clManager.activityType = .automotiveNavigation
        self.clManager.pausesLocationUpdatesAutomatically = true
        // --------------------------------------------------------------------------
        
        // Pedimos privilegios de actualización constante en SEGUNDO PLANO
        self.clManager.allowsBackgroundLocationUpdates = true
        self.clManager.showsBackgroundLocationIndicator = true
        
        // 2. Sincronizamos el estado inicial la primera vez que se crea la clase
        self.permissionState = mapAuthorizationStatus(clManager.authorizationStatus)
        
        // Encender el GPS desde el inicio
        self.clManager.startUpdatingLocation()
        }
    
    // MARK: - Intenciones
    func requestWhenInUseAuthorization() {
        clManager.requestWhenInUseAuthorization()
    }
    
    // petición para trabajar en segundo plano
    func requestAlwaysAuthorization() {
        clManager.requestAlwaysAuthorization()
    }
    
    // Asigna el manejador de ubicación
    func setLocationHandler(_ handler: @escaping (CLLocation) -> Void) {
            self.locationHandler = handler
        }
    
    // MARK: - Optimización Dinámica de Energía
        
    func enableEcoMode() {
        // Cuando la pantalla está bloqueada, bajamos la precisión a 3 kilómetros.
        // Esto apaga el satélite por completo y solo usa antenas de celular.
        // ¡Las geocercas (Geofences) siguen funcionando perfecto con esta configuración!
        clManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        clManager.distanceFilter = 500 // Solo avisar si se mueve medio kilómetro
        print("Modo ECO Activado: GPS al mínimo.")
    }
    
    func disableEcoMode() {
        // Cuando el usuario abre la app para ver por dónde va, devolvemos la precisión.
        clManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        clManager.distanceFilter = 50
        clManager.startUpdatingLocation() // Despierta el GPS y que mande ubicacion para el ETA
        print("Modo Normal: GPS restaurado para el mapa.")
    }
    
    // MARK: - Lógica Privada de Mapeo
    // lenguaje de Apple a nuestro dominio limpio
    private func mapAuthorizationStatus(_ status: CLAuthorizationStatus) -> LocationPermissionState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        case .authorizedAlways:
            return .authorizedAlways
        @unknown default:
            return .notDetermined
        }
    }
}

// MARK: - Delegado de CoreLocation
extension LocationManager: CLLocationManagerDelegate {
    
    // Este método es llamado por el sistema operativo cuando el usuario responde a la alerta de permisos.
    // Usamos 'nonisolated' porque los protocolos de Objective-C de Apple a veces envían callbacks
    // desde contextos no aislados. Luego, cruzamos de vuelta a la seguridad con Task { @MainActor in }.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        
        // Capturamos el nuevo estado crudo de forma segura
        let newStatus = manager.authorizationStatus
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            // Mutamos la variable observable estrictamente dentro del hilo principal
            self.permissionState = self.mapAuthorizationStatus(newStatus)
        }
    }
    
    //Escucha los movimientos del GPS en tiempo real
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Disparamos la ubicación hacia el ViewModel
                self.locationHandler?(location)
            }
        }
    
}
