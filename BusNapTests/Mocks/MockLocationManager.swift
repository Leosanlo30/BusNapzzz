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
    
    // Bandera espía para saber si el ViewModel llamó a la función
    var didRequestAuthorization = false
    
    init(initialState: LocationPermissionState = .notDetermined) {
        self.permissionState = initialState
    }
    
    func requestWhenInUseAuthorization() {
        didRequestAuthorization = true
    }
    
    func requestAlwaysAuthorization() {
        didRequestAuthorization = true
        permissionState = .authorizedAlways
    }
    
    func enableEcoMode() {}

    func disableEcoMode() {}

    func setDestination(_ coordinate: CLLocationCoordinate2D) {}

    func clearDestination() {}

    var distanceToDestination: CLLocationDistance? = nil

    func setLocationHandler(_ handler: @escaping (CLLocation) -> Void) {
        // Mock: no hacemos nada con el handler
    }
}
