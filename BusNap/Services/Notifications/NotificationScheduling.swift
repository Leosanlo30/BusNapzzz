//
//  NotificationScheduling.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 11/07/26.
//

import Foundation

/// Define el contrato para la gestión y programación de alertas locales en el sistema.
protocol NotificationScheduling: Sendable {
    /// Solicita autorización nativa al usuario para mostrar alertas sonoras y visuales.
    /// - Returns: `true` si el usuario otorgó los permisos necesarios.
    func requestAuthorization() async throws -> Bool
    
    /// Programar una alarma de despertar inmediata o programada con alta prioridad.
    /// - Parameters:
    ///   - title: Título principal de la alerta.
    ///   - body: Cuerpo del mensaje con detalles del destino.
    ///   - soundName: Nombre del archivo de sonido (sin extensión).
    func scheduleWakeUpAlarm(title: String, body: String, soundName: String) async throws
    
    /// Aborta y limpia cualquier alarma que esté en cola para sonar.
    func cancelPendingAlarms()
}

extension NotificationScheduling {
    /// Programar una alarma usando el tono por defecto ("alarm").
    func scheduleWakeUpAlarm(title: String, body: String) async throws {
        try await scheduleWakeUpAlarm(title: title, body: body, soundName: "alarm")
    }
}
