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
    var soundName: String = "alarm"
    
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
            self.handleCriticalZoneEntry(for: identifier, soundName: self.soundName)
        }
    }
    
    // MARK: - Intenciones (Ciclo de Vida)
    
    func startTrip(to destination: Destination, leadTime: AlertLeadTime, soundName: String = "alarm") {
        self.currentDestination = destination
        self.soundName = soundName
        
        self.state = .monitoring
        
        cancelActiveTask()
        
        let leadTimeSeconds = Double(leadTime.minutes * 60)
        let estimatedSpeed: Double = 5.5
        let radius = max(500.0, leadTimeSeconds * estimatedSpeed)
        
        geofenceMonitor.startMonitoring(destination: destination, radius: radius)
        
        monitoringTask = Task {
            // Aquí vivirá la lógica de red adaptativa
        }
    }
    
    func cancelTrip() {
        cancelActiveTask()
        self.currentDestination = nil
        
        geofenceMonitor.stopMonitoring()
        notificationManager.cancelPendingAlarms()
        
        AudioManager.shared.stopAlarm()
        
        self.state = .idle
    }
    
    func updateDestination(_ newDestination: Destination) {
        self.currentDestination = newDestination
        
        if state == .monitoring || state == .criticalZone {
            geofenceMonitor.stopMonitoring()
            notificationManager.cancelPendingAlarms()
            cancelActiveTask()
        }
        
        self.state = .configured
    }
    
    func updateDestinationName(_ name: String) {
        guard var dest = currentDestination else { return }
        dest.name = name
        self.currentDestination = dest
    }
    
    // MARK: - Manejadores de Eventos

    func triggerArrival(for destinationName: String, soundName: String) {
        handleCriticalZoneEntry(for: destinationName, soundName: soundName)
    }

    private func handleCriticalZoneEntry(for identifier: String, soundName: String) {
        guard state != .alarmTriggered else { return }
        Task { @MainActor in
            self.state = .criticalZone
            AudioManager.shared.playAlarm(soundName: soundName)
            
            let destName = self.currentDestination?.name ?? "tu parada"
            let title = "¡Despierta!"
            let body = "Estás llegando a \(destName). Es hora de bajar del autobús."
            
            do {
                try await notificationManager.scheduleWakeUpAlarm(title: title, body: body, soundName: soundName)
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
