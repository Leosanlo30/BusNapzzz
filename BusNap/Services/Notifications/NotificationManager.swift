//
//  NotificationManager.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 11/07/26.
//

import Foundation
import UserNotifications

/// Gestor principal del sistema de notificaciones nativo de iOS.
final class NotificationManager: NotificationScheduling, @unchecked Sendable {
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let alarmIdentifier = "BusNap.WakeUpAlarm"
    
    /// Solicita al sistema operativo los permisos para sonido, alertas y globos (badges).
    func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        
        do {
            let granted = try await notificationCenter.requestAuthorization(options: options)
            if granted {
                print(" NotificationManager: Permiso de alertas concedido.")
            } else {
                print(" NotificationManager: El usuario denegó los permisos de notificación.")
            }
            return granted
        } catch {
            print(" NotificationManager: Error al solicitar permisos - \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Dispara la alarma con prioridad máxima y sonido personalizado.
    func scheduleWakeUpAlarm(title: String, body: String, soundName: String = "alarm") async throws {
        // 1. Limpieza preventiva: Evitamos notificaciones duplicadas en cola
        cancelPendingAlarms()
        
        // 2. Configuración del contenido
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
        
        // 3. Interrupción de Alta Prioridad (Crucial para alarmas)
        // Permite atravesar modos de concentración si el usuario lo autoriza en iOS.
        content.interruptionLevel = .timeSensitive
        
        // 4. Configuración del Audio Personalizado
        // iOS buscará este archivo exactamente con este nombre dentro del bundle principal.
        content.sound = UNNotificationSound(named: UNNotificationSoundName("\(soundName).mp3"))
        
        // 5. Trigger (Disparador)
        // Como el Geofence ya hizo el cálculo de tiempo/espacio, disparamos la alerta
        // 1 segundo después de recibir la orden.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        
        // 6. Empaquetar y enviar la petición al sistema
        let request = UNNotificationRequest(
            identifier: alarmIdentifier,
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
        print(" Alarma programada con éxito: '\(title)'")
    }
    
    /// Elimina las alertas pendientes o que ya se entregaron en el Centro de Notificaciones.
    func cancelPendingAlarms() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [alarmIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [alarmIdentifier])
        print(" Alertas programadas y entregadas purgadas limpiamente.")
    }
}
