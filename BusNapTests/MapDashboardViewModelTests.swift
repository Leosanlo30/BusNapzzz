//
//  MapDashboardViewModelTests.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 08/07/26.
//

import Foundation
import Foundation
import Testing
@testable import BusNap // Da acceso a los tipos con control de acceso interno de la app

@MainActor
struct MapDashboardViewModelTests {

    // MARK: - Pruebas de Inicialización y Seguridad (Sprint 2)
    
    @Test("Verificar que el ViewModel está limpio y apagado al iniciar la app")
    func testInitialState() {
        let viewModel = MapDashboardViewModel()
        
        #expect(viewModel.alarmStatus == .idle)
        #expect(viewModel.selectedDestination == nil)
        #expect(viewModel.simulatedETA == nil)
        #expect(viewModel.leadTime == .fiveMinutes)
    }
    
    @Test("Verificar que NO podemos activar un viaje si no hay destino")
    func testActivationFailsWithoutDestination() {
        let viewModel = MapDashboardViewModel()
        
        // Intentamos activar sin haber configurado un destino
        viewModel.activateTrip()
        
        // El seguro lógico debe mantener el sistema inactivo
        #expect(viewModel.alarmStatus == .idle)
    }
    
    @Test("Verificar el flujo feliz (Happy Path) al activar un viaje")
        func testSuccessfulActivation() async throws {
            // 1. Preparamos la red simulada
            let mockEstimator = MockRouteEstimator(shouldFail: false, simulatedTime: 900)
            
            // 2. NUEVO: Preparamos el GPS simulado con "Pase VIP"
            let mockLocation = MockLocationManager(initialState: .authorizedAlways)
            
            // 3. Inyectamos ambos mocks al instanciar
            let viewModel = MapDashboardViewModel(
                routeEstimator: mockEstimator,
                locationManager: mockLocation
            )
            
            let testDestination = Destination(name: "Facultad de Matemáticas", latitude: 21.0478, longitude: -89.6242)
            
            // Act
            viewModel.updateDestination(testDestination)
            viewModel.activateTrip()
            
            // Esperamos a que la red simulada termine
            try await Task.sleep(nanoseconds: 600_000_000)
            
            // Assert: Ahora sí, el viaje arranca sin problemas
            #expect(viewModel.alarmStatus == .monitoring)
            #expect(viewModel.selectedDestination?.name == "Facultad de Matemáticas")
            #expect(viewModel.simulatedETA != nil)
        }
    
    @Test("Verificar que cancelar el viaje limpia todo el estado")
    func testCancelTripResetsState() {
        let viewModel = MapDashboardViewModel()
        let testDestination = Destination(name: "Centro", latitude: 20.9673, longitude: -89.6236)
        
        viewModel.updateDestination(testDestination)
        viewModel.activateTrip()
        
        // Ejecutamos la interrupción del viaje
        viewModel.cancelTrip()
        
        #expect(viewModel.alarmStatus == .idle)
        #expect(viewModel.selectedDestination == nil)
        #expect(viewModel.simulatedETA == nil)
    }
    
    // MARK: - Pruebas de Gestión de Destino (Sprint 3 - HU01)
    
    @Test("Validar que asignar un destino cambia la propiedad selectedDestination de nulo a poblado")
    func testUpdateDestinationSetsCoordinate() {
        // preparamos simulacion
        let viewModel = MapDashboardViewModel()
        let testDestination = Destination(name: "Destino Seleccionado", latitude: 21.1441, longitude: -86.7796)
        
        // Asertamos precondición: el destino debe nacer en nil
        #expect(viewModel.selectedDestination == nil)
        
        // ejecutamos simulacion
        viewModel.updateDestination(testDestination)
        
        // verificar estado (si se cumpliio)
        #expect(viewModel.selectedDestination != nil)
        #expect(viewModel.selectedDestination?.name == "Destino Seleccionado")
        #expect(viewModel.selectedDestination?.latitude == 21.1441)
        #expect(viewModel.selectedDestination?.longitude == -86.7796)
    }
    
    @Test("Verificar que al cambiar el destino durante un viaje, el sistema lo actualiza correctamente")
        func testChangeDestinationDuringActiveTrip() async throws {
            // 1. Arrange: Mocks con conexión perfecta y Pase VIP de GPS
            let mockEstimator = MockRouteEstimator(shouldFail: false, simulatedTime: 900)
            let mockLocation = MockLocationManager(initialState: .authorizedAlways)
            
            let viewModel = MapDashboardViewModel(
                routeEstimator: mockEstimator,
                locationManager: mockLocation
            )
            
            // Iniciamos un viaje válido primero
            let initialDestination = Destination(name: "Destino Original", latitude: 21.0478, longitude: -89.6242)
            viewModel.updateDestination(initialDestination)
            viewModel.activateTrip()
            
            // Damos tiempo a que el mock de ruta responda (0.6 seg)
            try await Task.sleep(nanoseconds: 600_000_000)
            
            // 2. Act: El usuario selecciona un nuevo punto en el mapa a mitad del viaje
            let newDestination = Destination(name: "Destino Nuevo", latitude: 20.9674, longitude: -89.6236)
            viewModel.updateDestination(newDestination)
            
            // Damos tiempo para el nuevo cálculo de ruta
            try await Task.sleep(nanoseconds: 600_000_000)
            
            // 3. Assert: Validamos que el ViewModel aceptó el nuevo destino sin colapsar
            #expect(viewModel.selectedDestination?.name == "Destino Nuevo")
            #expect(viewModel.simulatedETA != nil)
        }
    
    // MARK: - Pruebas de Red y Mocking (Sprint 4 - HU03)
        
        @Test("Verificar que un cálculo exitoso actualiza el ETA del ViewModel")
        func testSuccessfulRouteEstimation() async throws {
            // Arrange: Preparamos un mock que tardará 20 minutos (1200 segundos) en "llegar"
            let mockEstimator = MockRouteEstimator(shouldFail: false, simulatedTime: 1200)
            let viewModel = MapDashboardViewModel(routeEstimator: mockEstimator)
            let testDestination = Destination(name: "Universidad", latitude: 21.0478, longitude: -89.6242)
            
            // Act: El usuario selecciona el destino
            viewModel.updateDestination(testDestination)
            
            // Assert Intermedio: Inmediatamente el ViewModel debe entrar en estado de carga
            #expect(viewModel.isLoadingETA == true)
            
            // Pausamos el hilo del test durante 0.6 segundos para dejar que el Mock (que tarda 0.5s) termine su trabajo
            try await Task.sleep(nanoseconds: 600_000_000)
            
            // Assert Final: El estado de carga se apaga y recibimos el ETA
            #expect(viewModel.isLoadingETA == false)
            #expect(viewModel.simulatedETA == 1200)
            #expect(viewModel.errorMessage == nil)
        }
        
        @Test("Verificar que un error de red resetea el ETA y muestra el mensaje de fallo")
        func testFailedRouteEstimation() async throws {
            // Arrange: Preparamos un mock configurado para fallar
            let mockEstimator = MockRouteEstimator(shouldFail: true)
            let viewModel = MapDashboardViewModel(routeEstimator: mockEstimator)
            let testDestination = Destination(name: "Destino Inalcanzable", latitude: 0, longitude: 0)
            
            // Act
            viewModel.updateDestination(testDestination)
            
            // Esperamos a que la red simulada termine de fallar
            try await Task.sleep(nanoseconds: 600_000_000)
            
            // Assert Final: No hay ETA, ya no está cargando, y tenemos un mensaje de error rojo
            #expect(viewModel.isLoadingETA == false)
            #expect(viewModel.simulatedETA == nil)
            #expect(viewModel.errorMessage != nil)
        }
    
        // MARK: - Doble de Acción para Almacenamiento
        @MainActor
        final class MockPreferencesStore: UserPreferencesStoring {
            var memoryStorage: AlertLeadTime = .fiveMinutes
            var favoriteStorage: [Destination] = []

            func saveLeadTime(_ time: AlertLeadTime) {
                memoryStorage = time
            }

            func loadLeadTime() -> AlertLeadTime {
                return memoryStorage
            }

            func saveFavorites(_ favorites: [Destination]) {
                favoriteStorage = favorites
            }

            func loadFavorites() -> [Destination] {
                return favoriteStorage
            }
        }

        // ... Dentro de tu struct MapDashboardViewModelTests ...

        @Test("Validar que el ViewModel recupera correctamente el tiempo de anticipación guardado al inicializarse")
        func testViewModelLoadsSavedPreferencesOnCreation() async throws {
            // Arrange: Preparamos un store simulado que ya contiene 5 minutos grabados en memoria
            let mockStore = MockPreferencesStore()
            mockStore.memoryStorage = .fiveMinutes
            
            // Act: Instanciamos el ViewModel inyectando el store preparado
            let viewModel = MapDashboardViewModel(preferencesStore: mockStore)
            
            // Assert: Comprobamos que el estado inicial hereda el valor guardado en lugar del default
            #expect(viewModel.leadTime == .fiveMinutes)
        }

        @Test("Verificar que cambiar el tiempo de anticipación altera el estado y escribe los datos en persistencia")
        func testUpdatingLeadTimePersistsChanges() async throws {
            // Arrange
            let mockStore = MockPreferencesStore()
            let viewModel = MapDashboardViewModel(preferencesStore: mockStore)
            
            // Precondición: Nace con el valor base del mock
            #expect(mockStore.memoryStorage == .fiveMinutes)
            
            // Act: El usuario selecciona 10 minutos en la interfaz
            viewModel.updateLeadTime(.threeMinutes)
            
            // Assert: Comprobamos la sincronización en memoria viva y en la caja de persistencia
            #expect(viewModel.leadTime == .threeMinutes)
            #expect(mockStore.memoryStorage == .threeMinutes)
        }
    
    //OFFLINE
    @Test("Verificar que el ViewModel reacciona a la pérdida de red")
        func testViewModelDetectsOfflineStatus() async throws {
            // Arrange
            let mockNetwork = MockNetworkMonitor()
            let viewModel = MapDashboardViewModel(networkMonitor: mockNetwork)
            
            // Precondición: Nace asumiendo que sí hay internet
            #expect(viewModel.isOffline == false)
            
            // Act: Simulamos que el usuario entra a un túnel y pierde señal
            mockNetwork.simulateNetworkChange(isOffline: true)
            
            // Esperamos un instante microscópico para que el Task {@MainActor in} se complete
            try await Task.sleep(nanoseconds: 10_000_000)
            
            // Assert: El ViewModel debió actualizar su estado a true
            #expect(viewModel.isOffline == true)
        }
    
    // MARK: - Pruebas de Autorización y GPS (Sprint 6 - HU07)
        
        @Test("Comprobar que el estado de la alarma se congela en .inactive si el GPS está bloqueado")
        func testActivationBlockedWhenPermissionIsDenied() async throws {
            // Arrange: Forzamos el estado a denegado
            let mockLocation = MockLocationManager(initialState: .denied)
            let viewModel = MapDashboardViewModel(locationManager: mockLocation)
            
            // ¡Importante! Simulamos el toque en el mapa para habilitar el botón virtual
            let testDestination = Destination(name: "Destino de Prueba", latitude: 21.0, longitude: -89.0)
            viewModel.updateDestination(testDestination)
            
            // Act: El usuario intenta arrancar el viaje
            viewModel.activateTrip()
            
            // Assert: Al configurar un destino, el estado debe ser .configured, NO .idle
                #expect(viewModel.alarmStatus == .configured)
                #expect(viewModel.errorMessage == "No podemos activar la alarma sin acceso al GPS.")
        }
        
    @Test("Validar que el flujo happy path transiciona a .monitoring")
        func testActivationSucceedsWhenPermissionIsAlways() async throws {
            let mockLocation = MockLocationManager(initialState: .authorizedAlways)
            let viewModel = MapDashboardViewModel(locationManager: mockLocation)
            
            viewModel.updateDestination(Destination(name: "A", latitude: 0, longitude: 0))
            viewModel.activateTrip()
            
            // IMPORTANTE: El motor inicia el viaje. Esperamos a que la Task se ejecute.
            try await Task.sleep(nanoseconds: 100_000_000)
            
            #expect(viewModel.alarmStatus == .monitoring)
        }
        
    @Test("Verificar que la solicitud al sistema se dispara si el estado es notDetermined")
        func testRequestAuthorizationIsCalledWhenNotDetermined() async throws {
            let mockLocation = MockLocationManager(initialState: .notDetermined)
            let viewModel = MapDashboardViewModel(locationManager: mockLocation)
            
            let testDestination = Destination(name: "Destino Nuevo", latitude: 21.0, longitude: -89.0)
            viewModel.updateDestination(testDestination)
            
            // Act
            viewModel.activateTrip()
            
            // Assert: El viaje no arranca, pero el estado debería ser .configured (por el destino)
            // en lugar de .idle
            #expect(viewModel.alarmStatus == .configured)
            #expect(mockLocation.didRequestAuthorization == true)
        }
}
