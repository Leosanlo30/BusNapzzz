//
//  TripEngine.swift.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class TripEngine {
    
    // MARK: - Estado Público
    private(set) var state: TripState = .idle
    private(set) var currentDestination: Destination? = nil
    
    // MARK: - Dependencias Inyectadas
    @ObservationIgnored private let geofenceMonitor: GeofenceMonitor
    @ObservationIgnored private let notificationManager: NotificationScheduling
    
    // MARK: - Control de Tareas Concurrentes
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?
    
    // MARK: - Inicialización
    // Solución de concurrencia: Usamos opcionales (= nil) en los parámetros y
    // hacemos la inicialización dentro del cuerpo seguro del @MainActor.
    init(geofenceMonitor: GeofenceMonitor? = nil,
         notificationManager: NotificationScheduling? = nil) {
        
        self.geofenceMonitor = geofenceMonitor ?? GeofenceMonitor()
        self.notificationManager = notificationManager ?? NotificationManager()
        
        // Configuramos la escucha pasiva de la geocerca
        setupGeofenceBindings()
    }
    
    private func setupGeofenceBindings() {
        geofenceMonitor.onRegionEntered = { [weak self] identifier in
            guard let self = self else { return }
            self.handleCriticalZoneEntry(for: identifier)
        }
    }
    
    // MARK: - Intenciones (Ciclo de Vida)
    
    func startTrip(to destination: Destination) {
        self.currentDestination = destination
        
        Task { @MainActor in
            self.state = .monitoring
        }
        
        cancelActiveTask()
        
        // Delegamos la vigilancia perimetral (Radio default: 1000m)
        geofenceMonitor.startMonitoring(destination: destination, radius: 1000.0)
        
        monitoringTask = Task {
            // Aquí vivirá la lógica de red adaptativa
        }
    }
    
    func cancelTrip() {
        cancelActiveTask()
        self.currentDestination = nil
        
        // Limpieza absoluta
        geofenceMonitor.stopMonitoring()
        notificationManager.cancelPendingAlarms()
        
        AudioManager.shared.stopAlarm()//alarma cancelada
        
        Task { @MainActor in
            self.state = .idle
        }
    }
    
    func updateDestination(_ newDestination: Destination) {
            self.currentDestination = newDestination
            
            // CORRECCIÓN: Si el usuario toca el mapa, detenemos cualquier viaje activo.
            // Esto obliga a que el usuario tenga que presionar "Activar Viaje"
            // explícitamente para el nuevo punto.
            if state == .monitoring || state == .criticalZone {
                geofenceMonitor.stopMonitoring()
                notificationManager.cancelPendingAlarms()
                cancelActiveTask()
            }
            
            // Siempre regresamos al estado de configuración, esperando el botón.
            Task { @MainActor in
                self.state = .configured
            }
        }
    
    // MARK: - Manejadores de Eventos
    
    private func handleCriticalZoneEntry(for identifier: String) {
        Task { @MainActor in
            
            self.state = .criticalZone
            AudioManager.shared.playAlarm() // Alarma encendida
            
            let destName = self.currentDestination?.name ?? "tu parada"
            let title = "¡Despierta!"
            let body = "Estás llegando a \(destName). Es hora de bajar del autobús."
            
            
            do {
                try await notificationManager.scheduleWakeUpAlarm(title: title, body: body)
                self.state = .alarmTriggered
            } catch {
                print(" TripEngine: Falló el disparo de la alarma - \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Utilidades Privadas
    
    private func cancelActiveTask() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
}
