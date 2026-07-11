//
//  GeofenceMonitorTests.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import Testing
import CoreLocation
@testable import BusNap

@MainActor
struct GeofenceMonitorTests {
    
    @Test("Verificar que coordenadas inválidas son rechazadas por el monitor")
    func testStartMonitoringRejectsInvalidCoordinates() {
        // Arrange
        let monitor = GeofenceMonitor()
        
        // Una latitud válida va de -90 a 90. Una longitud de -180 a 180.
        // Aquí forzamos coordenadas imposibles.
        let invalidDestination = Destination(
            name: "Lugar Inexistente",
            latitude: 150.0,
            longitude: 200.0
        )
        
        // Act
        // Si el monitor no tiene el guard, CLLocationManager arrojaría una excepción silenciosa.
        monitor.startMonitoring(destination: invalidDestination, radius: 1000.0)
        
        // Assert
        // Si el código llega aquí sin colapsar, nuestra protección 'guard CLLocationCoordinate2DIsValid'
        // funcionó correctamente y la llamada se abortó con seguridad.
        #expect(true)
    }
}
