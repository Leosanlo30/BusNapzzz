//
//  NetworkMonitoring.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation

public protocol NetworkMonitoring: Sendable {
    /// Inyecta el bloque de código que se ejecutará cuando cambie el estado de la red
    func setStatusHandler(_ handler: @Sendable @escaping (Bool) -> Void)
    
    /// Enciende el monitor
    func start()
    
    /// Apaga el monitor (útil para liberar memoria si cancelamos el viaje)
    func stop()
}
