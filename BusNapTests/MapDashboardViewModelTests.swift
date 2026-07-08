//
//  MapDashboardViewModelTests.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 08/07/26.
//

import Foundation
import Testing
@testable import BusNap // Esto nos da acceso a las clases de nuestra app

@MainActor
struct MapDashboardViewModelTests {

    // Prueba: Verificar el ViewModel está limpio y apagado al iniciar la app
    @Test
    func testInitialState() {
        let viewModel = MapDashboardViewModel()
        
        #expect(viewModel.alarmStatus == .inactive)
        #expect(viewModel.selectedDestination == nil)
        #expect(viewModel.simulatedETA == nil)
        #expect(viewModel.leadTime == .fiveMinutes)
    }
    
    // Prueba: Verificar que NO podemos activar un viaje si no hay destino
    @Test
    func testActivationFailsWithoutDestination() {
        let viewModel = MapDashboardViewModel()
        
        // Intentamos activar sin haber configurado un destino
        viewModel.activateTrip()
        
        // El estado debe seguir inactivo
        #expect(viewModel.alarmStatus == .inactive)
    }
    
    // Prueba: Verificar el Happy Path al activar un viaje
    @Test
    func testSuccessfulActivation() {
        let viewModel = MapDashboardViewModel()
        let testDestination = Destination(name: "Facultad de Matemáticas", latitude: 21.0478, longitude: -89.6242)
        
        // Configurar el destino
        viewModel.updateDestination(testDestination)
        
        // Activar el viaje
        viewModel.activateTrip()
        
        // Verificar que la máquina de estados avanzó correctamente
        #expect(viewModel.alarmStatus == .monitoring)
        #expect(viewModel.selectedDestination?.name == "Facultad de Matemáticas")
        #expect(viewModel.simulatedETA != nil)
    }
    
    // Prueba: Verificar que cancelar limpia todo
    @Test
    func testCancelTripResetsState() {
        let viewModel = MapDashboardViewModel()
        let testDestination = Destination(name: "Centro", latitude: 20.9673, longitude: -89.6236)
        
        // Simulamos un viaje activo
        viewModel.updateDestination(testDestination)
        viewModel.activateTrip()
        
        // Ahora lo cancelamos
        viewModel.cancelTrip()
        
        // Verificamos que volvió al estado base
        #expect(viewModel.alarmStatus == .inactive)
        #expect(viewModel.selectedDestination == nil)
        #expect(viewModel.simulatedETA == nil)
    }
}
