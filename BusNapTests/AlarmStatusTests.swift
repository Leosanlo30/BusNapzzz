//
//  AlarmStatusTests.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 23/06/26.
//

import XCTest
@testable import BusNap

final class AlarmStatusTests: XCTestCase {

    func testIsActiveTripReturnsTrueForActiveStates() {
        // Arrange
        let monitoringState = AlarmStatus.monitoring
        let criticalState = AlarmStatus.criticalZone
        
        // Assert: Comprobamos que ambos estados se consideren "Activos" monitoring y criticalZone
        XCTAssertTrue(monitoringState.isActiveTrip, "El estado monitoring debe ser un viaje activo")
        XCTAssertTrue(criticalState.isActiveTrip, "El estado criticalZone debe ser un viaje activo")
    }
    
    func testIsActiveTripReturnsFalseForInactiveStates() {
        // Arrange
        //Declaramos varibales para probar que no esten activos las demas propiedades
        let inactiveState = AlarmStatus.inactive
        let configuredState = AlarmStatus.configured
        let triggeredState = AlarmStatus.triggered
        let cancelledState = AlarmStatus.cancelled
        
        // Assert: Comprobamos que el resto de estados NO se consideren activos
        XCTAssertFalse(inactiveState.isActiveTrip)
        XCTAssertFalse(configuredState.isActiveTrip)
        XCTAssertFalse(triggeredState.isActiveTrip)
        XCTAssertFalse(cancelledState.isActiveTrip)
    }
    
    func testDisplayStatusReturnsCorrectText() {
        // Arrange & Assert: Validamos el texto de la funcion coincida con la salida esperada para la UI
        XCTAssertEqual(AlarmStatus.monitoring.displayStatus, "Monitoreando ruta...")
        XCTAssertEqual(AlarmStatus.triggered.displayStatus, "Despierta")
    }
}
