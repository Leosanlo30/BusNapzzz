//
//  GeofenceMonitor.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import CoreLocation

/// Servicio dedicado exclusivamente a la creación y vigilancia de Geocercas (regiones circulares).
@MainActor
final class GeofenceMonitor: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    
    private let locationManager = CLLocationManager()
    
    /// Closure que se ejecutará cuando el dispositivo cruce el perímetro hacia adentro.
    /// Envía el identificador de la región (usualmente el nombre del destino).
    var onRegionEntered: ((String) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    /// Inicia el monitoreo de una geocerca circular alrededor del destino.
    /// - Parameters:
    ///   - destination: El modelo de destino con latitud y longitud.
    ///   - radius: El radio en metros de la "zona crítica" (default: 1000m).
    func startMonitoring(destination: Destination, radius: CLLocationDistance = 1000.0) {
        let coordinate = CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
        
        // 1. Validación de seguridad lógica: No registrar coordenadas absurdas
        guard CLLocationCoordinate2DIsValid(coordinate) else {
            print(" GeofenceMonitor: Intento de monitorear coordenadas inválidas.")
            return
        }
        
        // 2. Generar identificador único (Usamos el nombre o un UUID si no tiene)
        let regionIdentifier = destination.name ?? UUID().uuidString
        
        // 3. Crear la región circular
        let region = CLCircularRegion(center: coordinate, radius: radius, identifier: regionIdentifier)
        
        // 4. Configurar reglas de notificación
        region.notifyOnEntry = true
        region.notifyOnExit = false // Para BusNap solo nos importa la llegada
        
        // 5. Entregar la tarea al sistema operativo
        locationManager.startMonitoring(for: region)
        print("📍 Geocerca activada para: \(regionIdentifier) con \(radius)m de radio.")
    }
    
    /// Limpia la antena y detiene todas las vigilancias activas.
    func stopMonitoring() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        print(" Monitoreo de geocercas detenido y purgado.")
    }
    
    // MARK: - CLLocationManagerDelegate
    
    // CoreLocation llama a este método cuando cruzamos la frontera de la región.
    // Usamos 'nonisolated' porque el sistema operativo lo puede llamar desde otro hilo.
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print(" ¡Cruzamos la geocerca de la región: \(region.identifier)!")
        
        // Brincamos al hilo principal para avisarle al motor de forma segura
        Task { @MainActor in
            self.onRegionEntered?(region.identifier)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print(" Error en geocerca para \(region?.identifier ?? "Desconocido"): \(error.localizedDescription)")
    }
}
