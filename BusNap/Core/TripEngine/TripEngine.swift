//
//  TripEngine.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import OSLog
import Foundation
import CoreLocation
import Observation

/// Máquina de estados del viaje y despachador de la alarma.
///
/// ```
///  idle ──updateDestination──▶ configured ──startTrip──▶ monitoring
///   ▲                              ▲                        │
///   └──────── cancelTrip ──────────┴── updateDestination ───┤
///                                                           │ geocerca o < 100 m
///                                                           ▼
///                                                     alarmTriggered
/// ```
///
/// Hay dos disparadores de llegada, y solo el primero cuenta:
/// - **Geocerca** (radio = tiempo de aviso × velocidad estimada): la vigila iOS
///   aunque la app esté suspendida o terminada.
/// - **Umbral de 100 m** desde el GPS adaptativo, por si la geocerca se retrasa.
///
/// El viaje activo se persiste en `ActiveTripStoring` para sobrevivir a que iOS
/// termine la app y la relance en segundo plano al cruzar la geocerca.
@MainActor
@Observable
final class TripEngine {

    // MARK: - Estado Público

    private(set) var state: TripState = .idle
    private(set) var currentDestination: Destination?
    private(set) var activeTrip: ActiveTrip?

    /// Se invoca cuando la alarma se dispara, venga de la geocerca o del GPS.
    @ObservationIgnored var onAlarmTriggered: (() -> Void)?

    // MARK: - Constantes

    /// Velocidad media estimada de un autobús urbano (m/s ≈ 20 km/h).
    static let estimatedBusSpeed: CLLocationSpeed = 5.5
    /// Radio mínimo de la geocerca: por debajo, iOS la dispara con poca fiabilidad.
    static let minimumAlarmRadius: CLLocationDistance = 500
    /// Un viaje más largo que esto se considera abandonado al restaurar.
    static let maxTripDuration: TimeInterval = 4 * 3600

    /// Radio de la zona de alarma para un tiempo de aviso dado.
    static func alarmRadius(forLeadTimeMinutes minutes: Int) -> CLLocationDistance {
        max(minimumAlarmRadius, Double(minutes * 60) * estimatedBusSpeed)
    }

    var isMonitoring: Bool { state == .monitoring || state == .criticalZone }

    // MARK: - Dependencias

    @ObservationIgnored private let geofenceMonitor: GeofenceMonitoring
    @ObservationIgnored private let notificationManager: NotificationScheduling
    @ObservationIgnored private let alarmPlayer: AlarmPlaying
    @ObservationIgnored private let store: ActiveTripStoring

    // MARK: - Inicialización

    init(geofenceMonitor: GeofenceMonitoring? = nil,
         notificationManager: NotificationScheduling? = nil,
         alarmPlayer: AlarmPlaying? = nil,
         store: ActiveTripStoring? = nil) {
        self.geofenceMonitor = geofenceMonitor ?? GeofenceMonitor()
        self.notificationManager = notificationManager ?? NotificationManager()
        self.alarmPlayer = alarmPlayer ?? AudioManager.shared
        self.store = store ?? UserDefaultsActiveTripStore()

        self.geofenceMonitor.onRegionEntered = { [weak self] identifier in
            self?.handleRegionEntered(identifier)
        }
        restoreOrPurge()
    }

    /// Si iOS relanzó la app con un viaje en curso, lo recupera.
    /// Si no hay viaje válido, purga geocercas huérfanas de sesiones anteriores.
    private func restoreOrPurge() {
        guard let trip = store.load(),
              Date.now.timeIntervalSince(trip.startedAt) < Self.maxTripDuration else {
            store.clear()
            geofenceMonitor.stopMonitoring()
            return
        }
        activeTrip = trip
        currentDestination = trip.destination
        state = .monitoring // la geocerca sigue registrada en el sistema
        Log.trip.info("Viaje restaurado tras relanzamiento")
    }

    // MARK: - Ciclo de Vida

    func startTrip(to destination: Destination, leadTime: AlertLeadTime,
                   soundName: String = "alarm", vibrate: Bool = true) {
        let trip = ActiveTrip(
            id: UUID(),
            destination: destination,
            leadTimeMinutes: leadTime.minutes,
            soundName: soundName,
            vibrate: vibrate,
            startedAt: .now
        )
        activeTrip = trip
        currentDestination = destination
        store.save(trip)

        alarmPlayer.prepare()
        geofenceMonitor.startMonitoring(
            destination: destination,
            radius: Self.alarmRadius(forLeadTimeMinutes: leadTime.minutes),
            identifier: trip.regionIdentifier
        )
        state = .monitoring
    }

    func cancelTrip() {
        endMonitoring()
        currentDestination = nil
        alarmPlayer.stopAlarm()
        state = .idle
    }

    /// Cambiar de destino detiene cualquier viaje en curso y vuelve a configuración.
    func updateDestination(_ newDestination: Destination) {
        if isMonitoring { endMonitoring() }
        currentDestination = newDestination
        state = .configured
    }

    func updateDestinationName(_ name: String) {
        guard var dest = currentDestination else { return }
        dest.name = name
        currentDestination = dest
    }

    // MARK: - Permisos

    func requestNotificationPermissionIfNeeded() async -> NotificationPermission {
        await notificationManager.requestAuthorizationIfNeeded()
    }

    func notificationPermissionStatus() async -> NotificationPermission {
        await notificationManager.authorizationStatus()
    }

    // MARK: - Llegada

    /// Disparador por GPS (umbral de 100 m).
    func triggerArrival() {
        handleArrival()
    }

    private func handleRegionEntered(_ identifier: String) {
        // Ignoramos regiones que no pertenecen al viaje actual.
        guard identifier == activeTrip?.regionIdentifier else { return }
        handleArrival()
    }

    /// Transición síncrona e idempotente: la geocerca y el umbral de 100 m
    /// pueden llegar casi a la vez; solo el primero dispara la alarma.
    private func handleArrival() {
        guard isMonitoring, let trip = activeTrip else { return }
        state = .alarmTriggered
        endMonitoring()

        alarmPlayer.playAlarm(soundName: trip.soundName, vibrate: trip.vibrate)
        onAlarmTriggered?()

        let destinationName = trip.destination.name ?? "tu parada"
        Task { [notificationManager] in
            do {
                try await notificationManager.scheduleWakeUpAlarm(
                    title: "¡Despierta!",
                    body: "Estás llegando a \(destinationName). Es hora de bajar del autobús.",
                    soundName: trip.soundName
                )
            } catch {
                Log.trip.error("No se pudo programar la notificación: \(error.localizedDescription, privacy: .public)")
            }
        }
        Log.trip.info("Alarma disparada")
    }

    // MARK: - Privado

    private func endMonitoring() {
        geofenceMonitor.stopMonitoring()
        notificationManager.cancelPendingAlarms()
        store.clear()
        activeTrip = nil
    }
}
