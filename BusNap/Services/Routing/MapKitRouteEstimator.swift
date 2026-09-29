//
//  MapKitRouteEstimator.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import MapKit
import CoreLocation

enum RouteEstimationError: LocalizedError {
    case noRoute

    var errorDescription: String? {
        switch self {
        case .noRoute: "No encontramos una ruta hacia este destino."
        }
    }
}

struct MapKitRouteEstimator: RouteEstimating {

    func estimateRoute(to destination: Destination, from currentLocation: CLLocation?, mode: TravelMode) async throws -> RouteEstimate {
        switch mode {
        case .automobile, .walking:
            return try await directions(to: destination, from: currentLocation, type: mode.mapKitTransportType)
        case .transit:
            return try await transitEstimate(to: destination, from: currentLocation)
        }
    }

    /// Cuánto más tarda un autobús urbano que un coche en la misma ruta
    /// (paradas, ascensos y descensos).
    static let busDelayFactor: Double = 1.4

    // MARK: - Private

    /// Apple Maps solo da tiempos de transporte público (sin trazado) y no en
    /// todas las ciudades. Si no hay datos, estimamos con la distancia de la
    /// ruta por calles y la velocidad media de un autobús urbano.
    private func transitEstimate(to destination: Destination, from currentLocation: CLLocation?) async throws -> RouteEstimate {
        // La ruta por calles da el trazado a dibujar y la distancia real.
        let streetRoute = try await directions(to: destination, from: currentLocation, type: .automobile)

        if let eta = try? await MKDirections(request: request(to: destination, from: currentLocation, type: .transit)).calculateETA() {
            return RouteEstimate(expectedTravelTime: eta.expectedTravelTime,
                                 distance: eta.distance,
                                 path: streetRoute.path)
        }

        // Un autobús nunca es más rápido que un coche por la misma ruta: partimos
        // del tiempo en coche (que ya incluye tráfico) y sumamos paradas y ascensos.
        let estimatedTime = max(streetRoute.expectedTravelTime * Self.busDelayFactor,
                                streetRoute.distance / TravelMode.transit.averageSpeed)
        return RouteEstimate(expectedTravelTime: estimatedTime,
                             distance: streetRoute.distance,
                             path: streetRoute.path,
                             isApproximate: true)
    }

    private func directions(to destination: Destination, from currentLocation: CLLocation?,
                            type: MKDirectionsTransportType) async throws -> RouteEstimate {
        let response = try await MKDirections(request: request(to: destination, from: currentLocation, type: type)).calculate()

        guard let route = response.routes.first else {
            throw RouteEstimationError.noRoute
        }

        return RouteEstimate(
            expectedTravelTime: route.expectedTravelTime,
            distance: route.distance,
            path: Self.path(from: route.polyline)
        )
    }

    private func request(to destination: Destination, from currentLocation: CLLocation?,
                         type: MKDirectionsTransportType) -> MKDirections.Request {
        let request = MKDirections.Request()
        if let location = currentLocation {
            request.source = MKMapItem(location: location, address: nil)
        } else {
            request.source = MKMapItem.forCurrentLocation()
        }
        let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        request.destination = MKMapItem(location: destLocation, address: nil)
        request.transportType = type
        return request
    }

    private static func path(from polyline: MKPolyline) -> [RouteCoordinate] {
        var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))
        return coordinates.map { RouteCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
    }
}
