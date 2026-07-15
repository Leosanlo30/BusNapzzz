//
//  NetworkMonitor.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import Network

final class NetworkMonitor: NetworkMonitoring, @unchecked Sendable {
    
    private let monitor = NWPathMonitor()
    
    // Creamos un hilo de fondo exclusivo para vigilar la red
    private let queue = DispatchQueue(label: "com.busnap.NetworkMonitor")
    
    private var handler: (@Sendable (Bool) -> Void)?
    
    func setStatusHandler(_ handler: @Sendable @escaping (Bool) -> Void) {
        self.handler = handler
    }
    
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            // .satisfied significa que hay conexión a internet (Wi-Fi o Celular)
            let isOffline = path.status != .satisfied
            self?.handler?(isOffline)
        }
        monitor.start(queue: queue)
    }
    
    func stop() {
        monitor.cancel()
    }
}
