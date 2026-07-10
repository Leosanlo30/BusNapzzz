//
//  MapDashboardViewModelTests.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 08/07/26.
//

import Foundation
import Foundation
import Testing
@testable import BusNap // Da acceso a los tipos con control de acceso interno de la app

@MainActor
struct MapDashboardViewModelTests {

    // MARK: - Pruebas de Inicialización y Seguridad (Sprint 2)
    
    @Test("Verificar que el ViewModel está limpio y apagado al iniciar la app")
    func testInitialState() {
        let viewModel = MapDashboardViewModel()
        
        #expect(viewModel.alarmStatus == .inactive)
        #expect(viewModel.selectedDestination == nil)
        #expect(viewModel.simulatedETA == nil)
        #expect(viewModel.leadTime == .fiveMinutes)
    }
    
    @Test("Verificar que NO podemos activar un viaje si no hay destino")
    func testActivationFailsWithoutDestination() {
        let viewModel = MapDashboardViewModel()
        
        // Intentamos activar sin haber configurado un destino
        viewModel.activateTrip()
        
        // El seguro lógico debe mantener el sistema inactivo
        #expect(viewModel.alarmStatus == .inactive)
    }
    
    @Test("Verificar el flujo feliz (Happy Path) al activar un viaje")
    func testSuccessfulActivation() {
        let viewModel = MapDashboardViewModel()
        let testDestination = Destination(name: "Facultad de Matemáticas", latitude: 21.0478, longitude: -89.6242)
        
        viewModel.updateDestination(testDestination)
        viewModel.activateTrip()
        
        #expect(viewModel.alarmStatus == .monitoring)
        #expect(viewModel.selectedDestination?.name == "Facultad de Matemáticas")
        #expect(viewModel.simulatedETA != nil)
    }
    
    @Test("Verificar que cancelar el viaje limpia todo el estado")
    func testCancelTripResetsState() {
        let viewModel = MapDashboardViewModel()
        let testDestination = Destination(name: "Centro", latitude: 20.9673, longitude: -89.6236)
        
        viewModel.updateDestination(testDestination)
        viewModel.activateTrip()
        
        // Ejecutamos la interrupción del viaje
        viewModel.cancelTrip()
        
        #expect(viewModel.alarmStatus == .inactive)
        #expect(viewModel.selectedDestination == nil)
        #expect(viewModel.simulatedETA == nil)
    }
    
    // MARK: - Pruebas de Gestión de Destino (Sprint 3 - HU01)
    
    @Test("Validar que asignar un destino cambia la propiedad selectedDestination de nulo a poblado")
    func testUpdateDestinationSetsCoordinate() {
        // preparamos simulacion
        let viewModel = MapDashboardViewModel()
        let testDestination = Destination(name: "Destino Seleccionado", latitude: 21.1441, longitude: -86.7796)
        
        // Asertamos precondición: el destino debe nacer en nil
        #expect(viewModel.selectedDestination == nil)
        
        // ejecutamos simulacion
        viewModel.updateDestination(testDestination)
        
        // verificar estado (si se cumpliio)
        #expect(viewModel.selectedDestination != nil)
        #expect(viewModel.selectedDestination?.name == "Destino Seleccionado")
        #expect(viewModel.selectedDestination?.latitude == 21.1441)
        #expect(viewModel.selectedDestination?.longitude == -86.7796)
    }
    
    @Test("Validar que si el estado es monitoring, actualizar el destino reemplaza las coordenadas sin alterar el monitoreo")
    func testChangeDestinationDuringActiveTrip() {
        // Arrange
        let viewModel = MapDashboardViewModel()
        let firstDestination = Destination(name: "Origen Inicial", latitude: 20.9673, longitude: -89.6236)
        let newDestination = Destination(name: "Nuevo Destino Cambiado", latitude: 21.0478, longitude: -89.6242)
        
        // Llevamos la máquina de estados al flujo activo con el primer destino
        viewModel.updateDestination(firstDestination)
        viewModel.activateTrip()
        #expect(viewModel.alarmStatus == .monitoring)
        
        // Act (El usuario cambia de opinión en pleno movimiento y toca otra calle)
        viewModel.updateDestination(newDestination)
        
        // Assert
        #expect(viewModel.selectedDestination?.name == "Nuevo Destino Cambiado")
        #expect(viewModel.selectedDestination?.latitude == 21.0478)
        // Verificación crítica de caja negra: el loop de monitoreo NO debe caerse ni reiniciarse por mutar el modelo
        #expect(viewModel.alarmStatus == .monitoring)
    }
}
