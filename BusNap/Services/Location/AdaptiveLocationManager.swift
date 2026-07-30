import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class AdaptiveLocationManager: NSObject, LocationManaging {

    // MARK: - Public State
    private(set) var permissionState: LocationPermissionState = .notDetermined
    private(set) var currentAccuracy: CLLocationAccuracy = kCLLocationAccuracyThreeKilometers
    private(set) var distanceToDestination: CLLocationDistance? = nil

    // MARK: - Dependencies
    @ObservationIgnored private let clManager = CLLocationManager()
    @ObservationIgnored private var locationHandler: ((CLLocation) -> Void)?
    private var destination: CLLocation? = nil

    // MARK: - Thresholds
    private let farDistance: CLLocationDistance = 3_000
    private let mediumDistance: CLLocationDistance = 2_000
    private let nearDistance: CLLocationDistance = 1_000

    override init() {
        super.init()
        clManager.delegate = self
        clManager.activityType = .automotiveNavigation
        clManager.pausesLocationUpdatesAutomatically = true
        clManager.allowsBackgroundLocationUpdates = true
        clManager.showsBackgroundLocationIndicator = true
        permissionState = mapAuthorizationStatus(clManager.authorizationStatus)
        applyAccuracy(.far)
        clManager.startUpdatingLocation()
    }

    // MARK: - Destination

    func setDestination(_ coordinate: CLLocationCoordinate2D) {
        destination = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    func clearDestination() {
        destination = nil
        distanceToDestination = nil
    }

    // MARK: - Adaptive Accuracy

    private enum AccuracyLevel {
        case far
        case medium
        case near
    }

    private func accuracyLevel(for distance: CLLocationDistance) -> AccuracyLevel {
        switch distance {
        case ..<nearDistance: return .near
        case ..<mediumDistance: return .medium
        default: return .far
        }
    }

    private func applyAccuracy(_ level: AccuracyLevel) {
        switch level {
        case .far:
            clManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            clManager.distanceFilter = 500
            currentAccuracy = kCLLocationAccuracyThreeKilometers
        case .medium:
            clManager.desiredAccuracy = kCLLocationAccuracyKilometer
            clManager.distanceFilter = 200
            currentAccuracy = kCLLocationAccuracyKilometer
        case .near:
            clManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            clManager.distanceFilter = 10
            currentAccuracy = kCLLocationAccuracyBestForNavigation
        }
    }

    private func reevaluateAccuracy(for location: CLLocation) {
        guard let destination else {
            applyAccuracy(.far)
            return
        }

        let distance = location.distance(from: destination)
        distanceToDestination = distance

        let currentLevel = accuracyLevel(for: distance)

        var storedLevel: AccuracyLevel = .far
        switch currentAccuracy {
        case kCLLocationAccuracyThreeKilometers: storedLevel = .far
        case kCLLocationAccuracyKilometer: storedLevel = .medium
        case kCLLocationAccuracyBestForNavigation: storedLevel = .near
        default: storedLevel = .far
        }

        if currentLevel != storedLevel {
            applyAccuracy(currentLevel)
        }
    }

    // MARK: - LocationManaging Conformance

    func requestWhenInUseAuthorization() {
        clManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        clManager.requestAlwaysAuthorization()
    }

    func enableEcoMode() {
        clManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        clManager.distanceFilter = 500
        currentAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func disableEcoMode() {
        reevaluateAccuracy(for: clManager.location ?? CLLocation(latitude: 0, longitude: 0))
        clManager.startUpdatingLocation()
    }

    func setLocationHandler(_ handler: @escaping (CLLocation) -> Void) {
        locationHandler = handler
    }

    // MARK: - Private

    private func mapAuthorizationStatus(_ status: CLAuthorizationStatus) -> LocationPermissionState {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorizedWhenInUse: return .authorizedWhenInUse
        case .authorizedAlways: return .authorizedAlways
        @unknown default: return .notDetermined
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension AdaptiveLocationManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            permissionState = mapAuthorizationStatus(newStatus)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            reevaluateAccuracy(for: location)
            locationHandler?(location)
        }
    }
}
