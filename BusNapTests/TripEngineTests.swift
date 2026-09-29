//
//  TripEngineTests.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import Testing
@testable import BusNap

@MainActor
struct TripEngineTests {

    private let destination = Destination(name: "Test", latitude: 21.0, longitude: -89.6)

    @Test("Cancelar el viaje transiciona a idle y borra el viaje persistido")
    func testCancelTripResetsToIdle() {
        let env = TestEnvironment()
        let engine = env.makeEngine()

        engine.startTrip(to: destination, leadTime: .fiveMinutes)
        #expect(engine.state == .monitoring)
        #expect(env.tripStore.trip != nil)

        engine.cancelTrip()

        #expect(engine.state == .idle)
        #expect(env.tripStore.trip == nil)
        #expect(env.geofence.monitoredIdentifier == nil)
    }

    @Test("La geocerca usa el identificador del viaje, no el nombre del destino")
    func testGeofenceUsesTripIdentifier() {
        let env = TestEnvironment()
        let engine = env.makeEngine()

        engine.startTrip(to: destination, leadTime: .fiveMinutes)

        #expect(env.geofence.monitoredIdentifier == engine.activeTrip?.regionIdentifier)
        #expect(env.geofence.monitoredIdentifier?.contains("Test") == false)
        #expect(env.geofence.monitoredRadius == TripEngine.alarmRadius(forLeadTimeMinutes: 5))
    }

    @Test("Geocerca y umbral de 100 m a la vez disparan una sola alarma")
    func testArrivalIsIdempotent() async {
        let env = TestEnvironment()
        let engine = env.makeEngine()
        engine.startTrip(to: destination, leadTime: .fiveMinutes)

        env.geofence.simulateEntry()
        engine.triggerArrival()
        await waitUntil { env.notifications.scheduledCount > 0 }

        #expect(engine.state == .alarmTriggered)
        #expect(env.alarm.playCount == 1)
        #expect(env.notifications.scheduledCount == 1)
    }

    @Test("Una región ajena al viaje actual no dispara la alarma")
    func testForeignRegionIsIgnored() {
        let env = TestEnvironment()
        let engine = env.makeEngine()
        engine.startTrip(to: destination, leadTime: .fiveMinutes)

        env.geofence.onRegionEntered?("BusNap.trip.otro")

        #expect(engine.state == .monitoring)
        #expect(env.alarm.playCount == 0)
    }

    @Test("Sin viaje activo, una entrada de geocerca huérfana no suena")
    func testOrphanRegionDoesNotRing() {
        let env = TestEnvironment()
        let engine = env.makeEngine()

        env.geofence.onRegionEntered?("BusNap.trip.viejo")

        #expect(engine.state == .idle)
        #expect(env.alarm.playCount == 0)
    }

    @Test("Al iniciar sin viaje guardado se purgan geocercas huérfanas")
    func testPurgesOrphanRegionsOnLaunch() {
        let env = TestEnvironment()
        _ = env.makeEngine()

        #expect(env.geofence.stopCount == 1)
    }

    @Test("Restaura un viaje reciente tras un relanzamiento y la alarma suena con su configuración")
    func testRestoresActiveTrip() {
        let trip = ActiveTrip(id: UUID(), destination: destination, leadTimeMinutes: 3,
                              soundName: "alarm3", vibrate: false, startedAt: .now.addingTimeInterval(-600))
        let env = TestEnvironment(storedTrip: trip)
        let engine = env.makeEngine()

        #expect(engine.state == .monitoring)
        #expect(engine.currentDestination == destination)

        env.geofence.simulateEntry(identifier: trip.regionIdentifier)

        #expect(engine.state == .alarmTriggered)
        #expect(env.alarm.lastSound == "alarm3")
        #expect(env.alarm.lastVibrate == false)
    }

    @Test("Descarta viajes guardados demasiado antiguos")
    func testDiscardsStaleTrip() {
        let trip = ActiveTrip(id: UUID(), destination: destination, leadTimeMinutes: 5,
                              soundName: "alarm", vibrate: true, startedAt: .now.addingTimeInterval(-5 * 3600))
        let env = TestEnvironment(storedTrip: trip)
        let engine = env.makeEngine()

        #expect(engine.state == .idle)
        #expect(env.tripStore.trip == nil)
    }

    @Test("El radio de alarma nunca baja del mínimo")
    func testAlarmRadius() {
        #expect(TripEngine.alarmRadius(forLeadTimeMinutes: 1) == TripEngine.minimumAlarmRadius)
        #expect(TripEngine.alarmRadius(forLeadTimeMinutes: 5) == 5 * 60 * TripEngine.estimatedBusSpeed)
    }
}
