//
//  TripEngineTests.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import Testing
@testable import BusNap

@MainActor
struct TripEngineTests {
    
    @Test("Comprobar que cancelar el viaje transiciona a idle")
        func testCancelTripResetsToIdle() async throws { // Nota el 'async throws'
            let engine = TripEngine()
            let destination = Destination(name: "Test", latitude: 0, longitude: 0)
            
            engine.startTrip(to: destination, leadTime: .fiveMinutes)
            
            #expect(engine.state == .monitoring)
            
            engine.cancelTrip()
            
            // Damos un respiro al motor para procesar el cancel
            await Task.yield()
            #expect(engine.state == .idle)
        }
}
