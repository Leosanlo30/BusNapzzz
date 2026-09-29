//
//  NotificationManager.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 11/07/26.
//

import OSLog
import Foundation
import UserNotifications

/// Gestor principal del sistema de notificaciones nativo de iOS.
final class NotificationManager: NotificationScheduling, @unchecked Sendable {

    private let notificationCenter = UNUserNotificationCenter.current()
    private let alarmIdentifier = "BusNap.WakeUpAlarm"

    /// Solicita al sistema operativo los permisos para sonido y alertas.
    func requestAuthorization() async throws -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound])
            Log.notifications.info("Permiso de notificaciones: \(granted ? "concedido" : "denegado", privacy: .public)")
            return granted
        } catch {
            Log.notifications.error("Error al solicitar permisos: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func authorizationStatus() async -> NotificationPermission {
        switch await notificationCenter.notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .authorized
        @unknown default: .denied
        }
    }

    /// Dispara la alarma con prioridad máxima y sonido personalizado.
    func scheduleWakeUpAlarm(title: String, body: String, soundName: String = "alarm") async throws {
        // Evitamos notificaciones duplicadas en cola
        cancelPendingAlarms()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // Permite atravesar modos de concentración si el usuario lo autoriza en iOS.
        content.interruptionLevel = .timeSensitive
        // iOS buscará este archivo exactamente con este nombre dentro del bundle principal.
        content.sound = UNNotificationSound(named: UNNotificationSoundName("\(soundName).mp3"))

        // La geocerca ya hizo el cálculo de tiempo/espacio: disparamos casi de inmediato.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(identifier: alarmIdentifier, content: content, trigger: trigger)

        try await notificationCenter.add(request)
        Log.notifications.info("Alarma programada")
    }

    /// Elimina las alertas pendientes o que ya se entregaron en el Centro de Notificaciones.
    func cancelPendingAlarms() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [alarmIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [alarmIdentifier])
    }
}
