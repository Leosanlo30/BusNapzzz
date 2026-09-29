import OSLog
import Foundation
import CoreLocation
import Observation

/// GPS adaptativo: ajusta la precisión según la distancia al destino.
///
/// - Lejos (> 2 km): precisión de 3 km (antenas celulares, casi sin batería).
/// - Media (1–2 km): precisión de 1 km. En segundo plano se mantiene en "lejos".
/// - Cerca (< 1 km): precisión de navegación, siempre, para no pasarse de parada.
@MainActor
@Observable
final class AdaptiveLocationManager: NSObject, LocationManaging {

    // MARK: - Public State

    private(set) var permissionState: LocationPermissionState = .notDetermined
    private(set) var distanceToDestination: CLLocationDistance?

    // MARK: - Private State

    @ObservationIgnored private let clManager = CLLocationManager()
    @ObservationIgnored private var locationHandler: ((CLLocation) -> Void)?
    @ObservationIgnored private var authorizationHandler: ((LocationPermissionState) -> Void)?
    @ObservationIgnored private var destination: CLLocation?
    @ObservationIgnored private var level: AccuracyLevel?
    @ObservationIgnored private var isInBackground = false

    override init() {
        super.init()
        clManager.delegate = self
        clManager.activityType = .automotiveNavigation
        permissionState = LocationPermissionState(clManager.authorizationStatus)
        // Sin startUpdatingLocation(): el GPS solo se enciende durante un viaje.
    }

    // MARK: - Tracking

    func startTracking(to coordinate: CLLocationCoordinate2D) {
        destination = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        // Un autobús detenido en el tráfico NO debe pausar el GPS: en segundo
        // plano iOS no lo reanudaría y la alarma de proximidad no llegaría.
        clManager.pausesLocationUpdatesAutomatically = false
        if permissionState == .authorizedAlways {
            clManager.allowsBackgroundLocationUpdates = true
            clManager.showsBackgroundLocationIndicator = true
        }
        apply(.far)
        clManager.startUpdatingLocation()
        Log.location.info("Seguimiento de viaje iniciado")
    }

    func stopTracking() {
        clManager.stopUpdatingLocation()
        clManager.allowsBackgroundLocationUpdates = false
        destination = nil
        distanceToDestination = nil
        level = nil
        Log.location.info("Seguimiento de viaje detenido")
    }

    // MARK: - Energy

    func enableEcoMode() {
        isInBackground = true
        reevaluate(clManager.location)
    }

    func disableEcoMode() {
        isInBackground = false
        reevaluate(clManager.location)
    }

    // MARK: - Authorization

    func requestWhenInUseAuthorization() {
        clManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        clManager.requestAlwaysAuthorization()
    }

    func setLocationHandler(_ handler: @escaping (CLLocation) -> Void) {
        locationHandler = handler
    }

    func setAuthorizationHandler(_ handler: @escaping (LocationPermissionState) -> Void) {
        authorizationHandler = handler
    }

    // MARK: - Adaptive Accuracy

    private func reevaluate(_ location: CLLocation?) {
        guard let destination, let location else { return }
        let distance = location.distance(from: destination)
        distanceToDestination = distance

        let target = AccuracyLevel(distance: distance, inBackground: isInBackground)
        if target != level { apply(target) }
    }

    private func apply(_ newLevel: AccuracyLevel) {
        level = newLevel
        clManager.desiredAccuracy = newLevel.desiredAccuracy
        clManager.distanceFilter = newLevel.distanceFilter
    }

    fileprivate func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        let newState = LocationPermissionState(status)
        permissionState = newState
        // Si el usuario sube a "Siempre" con un viaje activo, habilitamos segundo plano.
        if newState == .authorizedAlways, destination != nil {
            clManager.allowsBackgroundLocationUpdates = true
            clManager.showsBackgroundLocationIndicator = true
        }
        authorizationHandler?(newState)
    }

    fileprivate func handleLocation(_ location: CLLocation) {
        reevaluate(location)
        locationHandler?(location)
    }
}

// MARK: - AccuracyLevel

private enum AccuracyLevel: Equatable {
    case far, medium, near

    init(distance: CLLocationDistance, inBackground: Bool) {
        switch distance {
        case ..<1_000: self = .near
        case ..<2_000: self = inBackground ? .far : .medium
        default: self = .far
        }
    }

    var desiredAccuracy: CLLocationAccuracy {
        switch self {
        case .far: kCLLocationAccuracyThreeKilometers
        case .medium: kCLLocationAccuracyKilometer
        case .near: kCLLocationAccuracyBestForNavigation
        }
    }

    var distanceFilter: CLLocationDistance {
        switch self {
        case .far: 500
        case .medium: 200
        case .near: 10
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension AdaptiveLocationManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.handleAuthorizationChange(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.handleLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Log.location.error("Error de ubicación: \(error.localizedDescription, privacy: .public)")
    }
}
