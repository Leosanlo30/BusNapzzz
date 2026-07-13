//
//  MockNetworkMonitor.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
@testable import BusNap

final class MockNetworkMonitor: NetworkMonitoring, @unchecked Sendable {
    private var handler: (@Sendable (Bool) -> Void)?
    
    func setStatusHandler(_ handler: @Sendable @escaping (Bool) -> Void) {
        self.handler = handler
    }
    
    func start() {
        // En el mock no arrancamos ningún hardware real
    }
    
    func stop() {}
    
    // Función exclusiva del mock para "apretar el botón de apagar internet"
    func simulateNetworkChange(isOffline: Bool) {
        handler?(isOffline)
    }
}
