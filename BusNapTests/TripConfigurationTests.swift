//
//  TripConfiguration.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 07/07/26.
//

import XCTest
@testable import BusNap // Asegúrate de que coincida con el nombre de tu target principal

@MainActor
final class TripConfigurationTests: XCTestCase {

    // MARK: - Tests de Inicialización
    
    func testInit_WithDefaultValues_SetsCorrectDefaults() {
        // Given
        let destination = Destination(name: "Estación Central", latitude: 20.9881, longitude: -89.6166)
        
        // When
        let config = TripConfiguration(destination: destination)
        
        // Then
        XCTAssertEqual(config.destination.name, "Estación Central")
        XCTAssertEqual(config.leadTime, .fiveMinutes, "El leadTime por defecto debe ser .fiveMinutes.")
        XCTAssertEqual(config.status, .configured, "El estado inicial por defecto debe ser .configured.")
    }
    
    func testInit_WithCustomValues_SetsCustomValues() {
        // Given
        let destination = Destination(name: "Parque", latitude: 20.9985, longitude: -89.6178)
        
        // When
        let config = TripConfiguration(
            destination: destination,
            leadTime: .threeMinutes,
            status: .monitoring
        )
        
        // Then
        XCTAssertEqual(config.leadTime, .threeMinutes, "Debe respetar el tiempo personalizado asignado.")
        XCTAssertEqual(config.status, .monitoring, "Debe respetar el estado asignado.")
    }

    // MARK: - Tests de Inmutabilidad (Value Semantics)
    
    func testUpdatingStatus_ReturnsNewInstanceAndDoesNotMutateOriginal() {
        // Given
        let destination = Destination(latitude: 21.1619, longitude: -86.8515)
        let initialConfig = TripConfiguration(destination: destination, status: .configured)
        
        // When - Ejecutamos la función pura para cambiar el estado
        let updatedConfig = initialConfig.updatingStatus(to: .monitoring)
        
        // Then - Verificamos que se comporte como un verdadero Struct (inmutable)
        XCTAssertEqual(initialConfig.status, .configured, "La instancia original NO debe cambiar su estado.")
        XCTAssertEqual(updatedConfig.status, .monitoring, "La nueva instancia devuelta debe tener el nuevo estado.")
    }

    // MARK: - Tests de Persistencia (Codable)
    
    func testTripConfiguration_CanBeEncodedAndDecoded() throws {
        // Given - Creamos una configuración de prueba
        let destination = Destination(name: "Casa", latitude: 20.9674, longitude: -89.6237)
        let originalConfig = TripConfiguration(
            destination: destination,
            leadTime: .custom(minutes: 12),
            status: .criticalZone
        )
        
        // When - Codificamos a JSON y decodificamos de vuelta (simulando UserDefaults)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalConfig)
        let decodedConfig = try decoder.decode(TripConfiguration.self, from: data)
        
        // Then - Validamos que ninguna pieza se perdió en la conversión
        XCTAssertEqual(originalConfig, decodedConfig, "La configuración decodificada debe ser exactamente idéntica a la original.")
    }
}
