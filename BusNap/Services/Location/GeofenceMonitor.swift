//
//  GeofenceMonitor.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import OSLog
import Foundation
import CoreLocation

/// Contrato de la vigilancia de geocercas, para poder simular entradas en tests.
@MainActor
protocol GeofenceMonitoring: AnyObject {
    /// Se ejecuta cuando el dispositivo entra en la región. Recibe su identificador.
    var onRegionEntered: ((String) -> Void)? { get set }
    func startMonitoring(destination: Destination, radius: CLLocationDistance, identifier: String)
    func stopMonitoring()
}

/// Servicio dedicado exclusivamente a la creación y vigilancia de Geocercas (regiones circulares).
///
/// Las regiones las vigila el sistema operativo, incluso con la app terminada:
/// iOS relanza la app en segundo plano al cruzar la frontera.
@MainActor
final class GeofenceMonitor: NSObject, GeofenceMonitoring {

    private let locationManager = CLLocationManager()

    var onRegionEntered: ((String) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    /// Inicia el monitoreo de una geocerca circular alrededor del destino.
    /// - Parameters:
    ///   - destination: El destino con latitud y longitud.
    ///   - radius: El radio en metros de la "zona crítica".
    ///   - identifier: Identificador estable de la región (el del viaje, no el nombre del destino).
    func startMonitoring(destination: Destination, radius: CLLocationDistance, identifier: String) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            Log.location.error("Geocercas no disponibles en este dispositivo")
            return
        }

        guard CLLocationCoordinate2DIsValid(destination.coordinate) else {
            Log.location.error("Coordenadas inválidas para geocerca")
            return
        }

        // Solo vigilamos un viaje a la vez: purgamos cualquier región previa.
        stopMonitoring()

        let clampedRadius = min(radius, locationManager.maximumRegionMonitoringDistance)
        let region = CLCircularRegion(center: destination.coordinate, radius: clampedRadius, identifier: identifier)
        region.notifyOnEntry = true
        region.notifyOnExit = false

        locationManager.startMonitoring(for: region)
        Log.location.info("Geocerca activada (\(clampedRadius, format: .fixed(precision: 0)) m)")
    }

    /// Detiene y purga todas las regiones vigiladas por la app,
    /// incluidas las que hayan quedado de sesiones anteriores.
    func stopMonitoring() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension GeofenceMonitor: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let identifier = region.identifier
        Task { @MainActor [weak self] in
            self?.onRegionEntered?(identifier)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Log.location.error("Fallo de geocerca: \(error.localizedDescription, privacy: .public)")
    }
}
