//
//  TripState.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation

/// Representa los estados finitos y exclusivos del motor de viaje.
enum TripState: String, Sendable, Equatable {
    /// La app está inactiva, esperando a que el usuario seleccione un destino.
    case idle
    
    /// Destino seleccionado, ETA calculado, esperando confirmación de inicio.
    case configured
    
    /// Viaje activo. El motor está consultando el ETA de forma adaptativa.
    case monitoring
    
    /// El usuario está muy cerca del destino (dentro del Lead Time). Monitoreo agresivo.
    case criticalZone
    
    /// ¡Hora de despertar! La alarma está sonando o vibrando.
    case alarmTriggered
    
    /// El usuario detuvo el viaje manualmente antes de llegar.
    case cancelled
}
