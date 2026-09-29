//
//  LocationManaging.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import CoreLocation

/// Contrato del servicio de ubicación. Opera en el hilo principal.
///
/// El GPS solo se enciende entre `startTracking(to:)` y `stopTracking()`.
/// Fuera de un viaje, el punto azul del mapa lo gestiona MapKit por su cuenta.
@MainActor
protocol LocationManaging: AnyObject {
    var permissionState: LocationPermissionState { get }
    var distanceToDestination: CLLocationDistance? { get }

    func requestWhenInUseAuthorization()
    func requestAlwaysAuthorization()

    /// Modo ahorro: la app pasó a segundo plano.
    func enableEcoMode()
    /// La app volvió a primer plano.
    func disableEcoMode()

    /// Recibe cada nueva ubicación mientras hay un viaje activo.
    func setLocationHandler(_ handler: @escaping (CLLocation) -> Void)
    /// Recibe cada cambio de permiso (p. ej. tras aceptar "Siempre").
    func setAuthorizationHandler(_ handler: @escaping (LocationPermissionState) -> Void)

    /// Enciende el GPS adaptativo hacia el destino, también en segundo plano.
    func startTracking(to coordinate: CLLocationCoordinate2D)
    /// Apaga el GPS y el permiso de segundo plano.
    func stopTracking()
}
