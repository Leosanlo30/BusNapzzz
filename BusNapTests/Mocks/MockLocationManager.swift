//
//  MockLocationManager.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import CoreLocation
@testable import BusNap

// Aislamos el Mock en el MainActor para cumplir el contrato seguro del protocolo
@MainActor
final class MockLocationManager: LocationManaging {

    var permissionState: LocationPermissionState
    var distanceToDestination: CLLocationDistance? = nil

    // Banderas espía para saber qué llamó el ViewModel
    var didRequestAuthorization = false
    private(set) var isTracking = false
    private(set) var trackingDestination: CLLocationCoordinate2D?

    private var locationHandler: ((CLLocation) -> Void)?
    private var authorizationHandler: ((LocationPermissionState) -> Void)?

    init(initialState: LocationPermissionState = .notDetermined) {
        self.permissionState = initialState
    }

    func requestWhenInUseAuthorization() {
        didRequestAuthorization = true
    }

    func requestAlwaysAuthorization() {
        didRequestAuthorization = true
    }

    func enableEcoMode() {}

    func disableEcoMode() {}

    func setLocationHandler(_ handler: @escaping (CLLocation) -> Void) {
        locationHandler = handler
    }

    func setAuthorizationHandler(_ handler: @escaping (LocationPermissionState) -> Void) {
        authorizationHandler = handler
    }

    func startTracking(to coordinate: CLLocationCoordinate2D) {
        isTracking = true
        trackingDestination = coordinate
    }

    func stopTracking() {
        isTracking = false
        trackingDestination = nil
        distanceToDestination = nil
    }

    // MARK: - Simulación

    /// Simula que el usuario responde al diálogo de permisos.
    func simulateAuthorization(_ state: LocationPermissionState) {
        permissionState = state
        authorizationHandler?(state)
    }

    /// Simula una lectura de GPS a `distance` metros del destino.
    func simulateLocation(distanceToDestination distance: CLLocationDistance) {
        distanceToDestination = distance
        locationHandler?(CLLocation(latitude: 21.0, longitude: -89.6))
    }
}
