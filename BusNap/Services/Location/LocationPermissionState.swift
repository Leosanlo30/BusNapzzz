//
//  LocationPermissionState.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation

/// Representa el estado actual de los permisos de ubicación de manera tipada.
/// Aísla nuestra lógica de negocio de los tipos crudos de CoreLocation.
enum LocationPermissionState: String, Sendable, Equatable {
    
    /// El usuario aún no ha recibido el cuadro de diálogo solicitando permiso.
    case notDetermined
    
    /// El dispositivo tiene restricciones activas (ej. Controles parentales) que bloquean la ubicación.
    case restricted
    
    /// El usuario rechazó explícitamente el permiso de ubicación para esta app o lo apagó en Configuración.
    case denied
    
    /// La app tiene permiso de leer el GPS, pero SOLO mientras la pantalla de la app esté visible.
    case authorizedWhenInUse
    
    /// La app tiene permiso para despertar en segundo plano y leer el GPS (Vital para nuestra alarma).
    case authorizedAlways
}
