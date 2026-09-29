//
//  MapDashboardViewModelTests.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 08/07/26.
//

import Foundation
import Testing
@testable import BusNap

@MainActor
struct MapDashboardViewModelTests {

    private let facultad = Destination(name: "Facultad de Matemáticas", latitude: 21.0478, longitude: -89.6242)
    private let centro = Destination(name: "Centro", latitude: 20.9673, longitude: -89.6236)

    // MARK: - Inicialización y Seguridad

    @Test("El ViewModel nace limpio y apagado")
    func testInitialState() {
        let viewModel = TestEnvironment().makeViewModel()

        #expect(viewModel.alarmStatus == .idle)
        #expect(viewModel.selectedDestination == nil)
        #expect(viewModel.simulatedETA == nil)
        #expect(viewModel.leadTime == .fiveMinutes)
    }

    @Test("No se puede activar un viaje sin destino")
    func testActivationFailsWithoutDestination() {
        let env = TestEnvironment()
        let viewModel = env.makeViewModel()

        viewModel.activateTrip()

        #expect(viewModel.alarmStatus == .idle)
        #expect(env.location.isTracking == false)
    }

    @Test("Flujo feliz: activar un viaje monitorea, enciende el GPS y guarda el reciente")
    func testSuccessfulActivation() async {
        let env = TestEnvironment()
        let viewModel = env.makeViewModel()

        viewModel.updateDestination(facultad)
        viewModel.activateTrip()
        await waitUntil { viewModel.simulatedETA != nil }

        #expect(viewModel.alarmStatus == .monitoring)
        #expect(viewModel.selectedDestination?.name == "Facultad de Matemáticas")
        #expect(viewModel.simulatedETA != nil)
        #expect(env.location.isTracking)
        #expect(env.preferences.recentStorage.first?.name == "Facultad de Matemáticas")
    }

    @Test("Cancelar el viaje limpia el estado y apaga el GPS")
    func testCancelTripResetsState() {
        let env = TestEnvironment()
        let viewModel = env.makeViewModel()

        viewModel.updateDestination(centro)
        viewModel.activateTrip()
        viewModel.cancelTrip()

        #expect(viewModel.alarmStatus == .idle)
        #expect(viewModel.selectedDestination == nil)
        #expect(viewModel.simulatedETA == nil)
        #expect(env.location.isTracking == false)
        #expect(env.tripStore.trip == nil)
    }

    // MARK: - Gestión de Destino

    @Test("Asignar un destino puebla selectedDestination")
    func testUpdateDestinationSetsCoordinate() {
        let viewModel = TestEnvironment().makeViewModel()
        let destination = Destination(name: "Destino Seleccionado", latitude: 21.1441, longitude: -86.7796)

        #expect(viewModel.selectedDestination == nil)
        viewModel.updateDestination(destination)

        #expect(viewModel.selectedDestination == destination)
        #expect(viewModel.alarmStatus == .configured)
    }

    @Test("Cambiar de destino durante un viaje lo detiene y recalcula el ETA")
    func testChangeDestinationDuringActiveTrip() async {
        let env = TestEnvironment()
        let viewModel = env.makeViewModel()

        viewModel.updateDestination(facultad)
        viewModel.activateTrip()
        #expect(env.location.isTracking)

        viewModel.updateDestination(centro)
        await waitUntil { viewModel.simulatedETA != nil }

        #expect(viewModel.selectedDestination?.name == "Centro")
        #expect(viewModel.alarmStatus == .configured)
        #expect(env.location.isTracking == false)
        #expect(viewModel.simulatedETA != nil)
    }

    @Test("Tocar el mapa durante un viaje no cambia el destino")
    func testMapTapIgnoredDuringTrip() {
        let viewModel = TestEnvironment().makeViewModel()
        viewModel.updateDestination(facultad)
        viewModel.activateTrip()

        viewModel.handleMapTap(at: centro.coordinate)

        #expect(viewModel.selectedDestination?.name == "Facultad de Matemáticas")
        #expect(viewModel.alarmStatus == .monitoring)
    }

    // MARK: - ETA

    @Test("Un cálculo exitoso actualiza ETA, distancia y hora de llegada")
    func testSuccessfulRouteEstimation() async {
        let viewModel = TestEnvironment().makeViewModel(routeEstimator: MockRouteEstimator(simulatedTime: 1200))

        viewModel.updateDestination(facultad)
        #expect(viewModel.isLoadingETA == true)

        await waitUntil { !viewModel.isLoadingETA }

        #expect(viewModel.simulatedETA == 1200)
        #expect(viewModel.routeDistance == 5000)
        #expect(viewModel.estimatedArrival != nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Un error de red deja el ETA vacío y muestra el mensaje")
    func testFailedRouteEstimation() async {
        let viewModel = TestEnvironment().makeViewModel(routeEstimator: MockRouteEstimator(shouldFail: true))

        viewModel.updateDestination(Destination(name: "Destino Inalcanzable", latitude: 0, longitude: 0))
        await waitUntil { !viewModel.isLoadingETA }

        #expect(viewModel.simulatedETA == nil)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("Una respuesta lenta del destino anterior no pisa el ETA del nuevo")
    func testStaleETAIsDiscarded() async {
        var estimator = MockRouteEstimator()
        estimator.timesByDestinationName = ["Facultad de Matemáticas": 111, "Centro": 222]
        estimator.delaysByDestinationName = ["Facultad de Matemáticas": .milliseconds(300), "Centro": .milliseconds(20)]
        let viewModel = TestEnvironment().makeViewModel(routeEstimator: estimator)

        viewModel.updateDestination(facultad)
        viewModel.updateDestination(centro)
        await waitUntil { viewModel.simulatedETA != nil }
        try? await Task.sleep(for: .milliseconds(400)) // deja terminar la petición vieja

        #expect(viewModel.simulatedETA == 222)
    }

    // MARK: - Preferencias

    @Test("Recupera el tiempo de aviso guardado al inicializarse")
    func testViewModelLoadsSavedPreferencesOnCreation() {
        let env = TestEnvironment()
        env.preferences.memoryStorage = .threeMinutes

        let viewModel = env.makeViewModel()

        #expect(viewModel.leadTime == .threeMinutes)
    }

    @Test("Cambiar el tiempo de aviso lo persiste")
    func testUpdatingLeadTimePersistsChanges() {
        let env = TestEnvironment()
        let viewModel = env.makeViewModel()

        viewModel.updateLeadTime(.threeMinutes)

        #expect(viewModel.leadTime == .threeMinutes)
        #expect(env.preferences.memoryStorage == .threeMinutes)
    }

    @Test("La vibración desactivada en Ajustes llega a la alarma")
    func testVibrationSettingIsRespected() {
        let env = TestEnvironment()
        env.settings.vibrationEnabled = false
        env.settings.ringtoneName = "alarm2"
        let viewModel = env.makeViewModel()

        viewModel.updateDestination(facultad)
        viewModel.activateTrip()
        env.location.simulateLocation(distanceToDestination: 50)

        #expect(env.alarm.lastVibrate == false)
        #expect(env.alarm.lastSound == "alarm2")
    }

    @Test("Los recientes no se duplican y el más nuevo va primero")
    func testRecentsAreDeduplicated() {
        let env = TestEnvironment()
        let viewModel = env.makeViewModel()

        for destination in [facultad, centro, facultad] {
            viewModel.updateDestination(destination)
            viewModel.activateTrip()
            viewModel.cancelTrip()
        }

        #expect(viewModel.recentDestinations.map(\.name) == ["Facultad de Matemáticas", "Centro"])
    }

    // MARK: - Red

    @Test("El ViewModel reacciona a la pérdida de red")
    func testViewModelDetectsOfflineStatus() async {
        let env = TestEnvironment()
        let viewModel = env.makeViewModel()
        #expect(viewModel.isOffline == false)

        env.network.simulateNetworkChange(isOffline: true)
        await waitUntil { viewModel.isOffline }

        #expect(viewModel.isOffline == true)
    }

    // MARK: - Autorización y GPS

    @Test("Con el GPS denegado el viaje no arranca y se ofrece abrir Ajustes")
    func testActivationBlockedWhenPermissionIsDenied() {
        let env = TestEnvironment(permission: .denied)
        let viewModel = env.makeViewModel()

        viewModel.updateDestination(Destination(name: "Destino de Prueba", latitude: 21.0, longitude: -89.0))
        viewModel.activateTrip()

        #expect(viewModel.alarmStatus == .configured)
        #expect(viewModel.errorMessage == "No podemos activar la alarma sin acceso al GPS.")
        #expect(viewModel.errorNeedsSettings)
    }

    @Test("Con permiso 'Siempre' el viaje pasa a .monitoring")
    func testActivationSucceedsWhenPermissionIsAlways() {
        let viewModel = TestEnvironment().makeViewModel()

        viewModel.updateDestination(Destination(name: "A", latitude: 0, longitude: 0))
        viewModel.activateTrip()

        #expect(viewModel.alarmStatus == .monitoring)
    }

    @Test("Si el permiso no está decidido se pide y el viaje arranca al concederlo")
    func testTripStartsAfterPermissionGranted() {
        let env = TestEnvironment(permission: .notDetermined)
        let viewModel = env.makeViewModel()

        viewModel.updateDestination(Destination(name: "Destino Nuevo", latitude: 21.0, longitude: -89.0))
        viewModel.activateTrip()

        #expect(viewModel.alarmStatus == .configured)
        #expect(env.location.didRequestAuthorization == true)

        env.location.simulateAuthorization(.authorizedAlways)

        #expect(viewModel.alarmStatus == .monitoring)
        #expect(env.location.isTracking)
    }

    @Test("Iniciar un viaje pide permiso de notificaciones")
    func testNotificationPermissionRequestedOnTripStart() async {
        let env = TestEnvironment()
        env.notifications.grantOnRequest = false
        let viewModel = env.makeViewModel()

        viewModel.updateDestination(facultad)
        viewModel.activateTrip()
        await waitUntil { viewModel.notificationPermission == .denied }

        #expect(env.notifications.requestCount == 1)
        #expect(viewModel.notificationPermission == .denied)
    }

    // MARK: - Llegada

    @Test("A menos de 100 m se dispara la alarma y se apaga el GPS")
    func testArrivalThresholdTriggersAlarm() {
        let env = TestEnvironment()
        let viewModel = env.makeViewModel()

        viewModel.updateDestination(facultad)
        viewModel.activateTrip()
        env.location.simulateLocation(distanceToDestination: 800)
        #expect(viewModel.alarmStatus == .monitoring)

        env.location.simulateLocation(distanceToDestination: 80)

        #expect(viewModel.alarmStatus == .alarmTriggered)
        #expect(viewModel.tripUIState == .finished)
        #expect(env.alarm.playCount == 1)
        #expect(env.location.isTracking == false)
    }

    @Test("Detener la alarma apaga el sonido y vuelve al inicio")
    func testDismissFinishedStopsAlarm() {
        let env = TestEnvironment()
        let viewModel = env.makeViewModel()
        viewModel.updateDestination(facultad)
        viewModel.activateTrip()
        env.geofence.simulateEntry()
        #expect(env.alarm.isPlaying)

        viewModel.dismissFinished()

        #expect(env.alarm.isPlaying == false)
        #expect(viewModel.tripUIState == .initial)
    }

    @Test("Un viaje restaurado tras relanzar la app reanuda el GPS")
    func testRestoredTripResumesTracking() {
        let trip = ActiveTrip(id: UUID(), destination: facultad, leadTimeMinutes: 5,
                              soundName: "alarm", vibrate: true, startedAt: .now)
        let env = TestEnvironment(storedTrip: trip)

        let viewModel = env.makeViewModel()

        #expect(viewModel.alarmStatus == .monitoring)
        #expect(viewModel.selectedDestination == facultad)
        #expect(env.location.isTracking)
    }
}
