//
//  MockLocationManager.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
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
        // En un test, no levantamos el diálogo de Apple.
        // Simplemente registramos que la intención ocurrió.
    }
}
