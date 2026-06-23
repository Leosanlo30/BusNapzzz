//
//  AlertLeadTimeTests.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 22/06/26.
//
import XCTest
@testable import BusNap

final class AlertLeadTimeTests: XCTestCase {
    
    func testSafeCustomClampsNegativeValues() {
        // Arrange & Act
        let leadTime = AlertLeadTime.safeCustom(minutes: -5)
        
        // Assert: Comprobamos que el valor negativo se reajustó a 1
        XCTAssertEqual(leadTime.minutes, 1, "Los valores negativos deben ajustarse a 1")
    }

    func testSafeCustomClampsValuesAbove19() {
        // Arrange & Act
        let leadTime = AlertLeadTime.safeCustom(minutes: 25)
        
        // Assert: Comprobamos que el valor excesivo se reajustó a 19
        XCTAssertEqual(leadTime.minutes, 19, "Los valores mayores a 19 deben ajustarse a 19")
    }

    func testSafeCustomAllowsValidValues() {
        // Arrange & Act
        let leadTime = AlertLeadTime.safeCustom(minutes: 12)
        
        // Assert: Comprobamos que el valor válido se mantiene igual
        XCTAssertEqual(leadTime.minutes, 12, "Los valores entre 1 y 19 deben mantenerse intactos")
    }
}
