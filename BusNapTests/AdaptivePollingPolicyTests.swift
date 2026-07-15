//
//  AdaptivePollingPolicyTests.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import Testing
@testable import BusNap

struct AdaptivePollingPolicyTests {
    private let policy = AdaptivePollingPolicy()
    
    @Test("Validar que ETA de 10 min retorna 5 min de espera")
    func testEtaTenMinutesReturnsFive() {
        let eta: TimeInterval = 600 // 10 min
        let sleep = policy.calculateSleepTime(for: eta)
        #expect(sleep == 300) // 5 min
    }
    
    @Test("Validar que un ETA muy bajo retorna el mínimo de seguridad")
    func testLowEtaReturnsMinimum() {
        let eta: TimeInterval = 10 // 10 segundos
        let sleep = policy.calculateSleepTime(for: eta)
        #expect(sleep == policy.minimumSleepTime)
    }
    
    @Test("Validar que un ETA muy largo retorna el máximo de seguridad")
    func testVeryLongEtaReturnsMaximum() {
        let eta: TimeInterval = 3600 // 1 hora
        let sleep = policy.calculateSleepTime(for: eta)
        #expect(sleep == policy.maximumSleepTime)
    }
}
