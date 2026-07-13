//
//  AdaptivePollingPolicy.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation

/// Política matemática para calcular los intervalos de inactividad,
/// optimizando el uso de batería y red durante el viaje.
struct AdaptivePollingPolicy: Sendable {
    
    // MARK: - Límites de Seguridad (Constantes)
    
    /// El tiempo mínimo que el motor debe dormir. Evita saturar la red y a Apple Maps si el ETA es muy bajo.
    let minimumSleepTime: TimeInterval = 30 // 30 segundos
    
    /// El tiempo máximo que el motor puede dormir. Garantiza que la app no se "desconecte" por demasiado tiempo en viajes largos.
    let maximumSleepTime: TimeInterval = 300 // 5 minutos (5 * 60)
    
    // MARK: - Lógica de Cálculo
    
    /// Calcula el tiempo óptimo que el motor debe pausar antes de volver a consultar la ruta.
    /// - Parameter eta: Tiempo estimado de llegada actual en segundos.
    /// - Returns: Intervalo en segundos que el motor debe dormir.
    func calculateSleepTime(for eta: TimeInterval) -> TimeInterval {
        // Si por alguna razón el ETA es inválido o negativo, aplicamos el mínimo por seguridad
        guard eta > 0 else { return minimumSleepTime }
        
        // Regla de Oro: Dormir la mitad del tiempo restante
        let rawSleepTime = eta / 2.0
        
        // Clamping: Restringimos el resultado matemático a nuestros límites de seguridad.
        // En Swift usamos max() y min() anidados para acotar un valor entre un límite inferior y superior.
        let clampedSleepTime = max(minimumSleepTime, min(rawSleepTime, maximumSleepTime))
        
        return clampedSleepTime
    }
}
