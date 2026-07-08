//
//  TripMathTests.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 07/07/26.
//


import XCTest
@testable import BusNap 

final class TripMathTests: XCTestCase {

    // MARK: - Adaptive Polling Sleep Tests
    
    func testCalculateInitialSleep_ReturnsHalfETA() {
        // Given
        let eta: TimeInterval = 600.0 // 10 minutos
        let expectedSleep: TimeInterval = 300.0 // 5 minutos
        
        // When
        let result = TripMath.calculateInitialSleep(for: eta)
        
        // Then
        XCTAssertEqual(result, expectedSleep, "TripMath debe devolver exactamente ETA / 2.")
    }
    
    func testCalculateInitialSleep_NeverReturnsNegativeSleep() {
        // Given
        let negativeETA: TimeInterval = -120.0
        
        // When
        let result = TripMath.calculateInitialSleep(for: negativeETA)
        
        // Then
        XCTAssertEqual(result, 0, "TripMath nunca debe devolver un sleep negativo.")
    }

    // MARK: - Critical Threshold Tests
    
    func testIsCriticalThresholdReached_ActivatesWithETALessThanOrEqual3Minutes() {
        // Given
        let exactThresholdETA: TimeInterval = 180.0 // Exactamente 3 minutos
        let safeDistance: Double = 5000.0 // 5 km (distancia segura para no viciar el test)
        
        // When
        let result = TripMath.isCriticalThresholdReached(eta: exactThresholdETA, distance: safeDistance)
        
        // Then
        XCTAssertTrue(result, "El umbral crítico se debe activar con un ETA menor o igual a 3 minutos.")
    }
    
    func testIsCriticalThresholdReached_ActivatesWithDistanceLessThanOrEqual1Km() {
        // Given
        let safeETA: TimeInterval = 600.0 // 10 minutos (ETA seguro para no viciar el test)
        let exactThresholdDistance: Double = 1000.0 // Exactamente 1 km
        
        // When
        let result = TripMath.isCriticalThresholdReached(eta: safeETA, distance: exactThresholdDistance)
        
        // Then
        XCTAssertTrue(result, "El umbral crítico se debe activar con una distancia menor o igual a 1 km.")
    }
}
