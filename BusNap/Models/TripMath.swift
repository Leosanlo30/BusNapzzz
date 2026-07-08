//
//  TripMath.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 07/07/26.
//

import Foundation

/// Módulo de utilidades matemáticas para los cálculos de ruta y Adaptive Polling.
public enum TripMath {
    
    /// Calcula el tiempo de 'sleep' inicial para el Adaptive Polling.
    ///
    /// - Parameter eta: El tiempo estimado de llegada restante en segundos.
    /// - Returns: El intervalo de espera recomendado en segundos. Garantiza nunca ser negativo.
    public static func calculateInitialSleep(for eta: TimeInterval) -> TimeInterval {
        // Evitamos sleeps negativos si el ETA devuelto por el sistema es anómalo
        guard eta > 0 else { return 0 }
        
        return eta / 2.0
    }
    
    /// Determina si el pasajero ha entrado en el umbral crítico para preparar la alerta.
    ///
    /// - Parameters:
    ///   - eta: El tiempo estimado de llegada en segundos.
    ///   - distance: La distancia restante en metros.
    /// - Returns: `true` si el ETA es de 3 minutos o menos, o si la distancia es de 1 km o menos.
    public static func isCriticalThresholdReached(eta: TimeInterval, distance: Double) -> Bool {
        let threeMinutesInSeconds: TimeInterval = 180.0
        let oneKilometerInMeters: Double = 1000.0
        
        // Se activa si se cumple CUALQUIERA de las dos condiciones
        return eta <= threeMinutesInSeconds || distance <= oneKilometerInMeters
    }
}
