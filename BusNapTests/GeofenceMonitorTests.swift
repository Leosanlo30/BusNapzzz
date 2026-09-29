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

    @Test("Coordenadas inválidas son rechazadas sin colapsar")
    func testStartMonitoringRejectsInvalidCoordinates() {
        let monitor = GeofenceMonitor()
        let invalidDestination = Destination(name: "Lugar Inexistente", latitude: 150.0, longitude: 200.0)

        // Si el guard 'CLLocationCoordinate2DIsValid' no existiera, CoreLocation fallaría.
        monitor.startMonitoring(destination: invalidDestination, radius: 1000.0, identifier: "test")
        monitor.stopMonitoring()
    }
}
