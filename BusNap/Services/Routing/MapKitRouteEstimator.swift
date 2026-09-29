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

    func estimateRoute(to destination: Destination, from currentLocation: CLLocation? = nil) async throws -> RouteEstimate {
        let request = MKDirections.Request()

        if let location = currentLocation {
            request.source = MKMapItem(location: location, address: nil)
        } else {
            request.source = MKMapItem.forCurrentLocation()
        }

        let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        request.destination = MKMapItem(location: destLocation, address: nil)
        // MapKit no ofrece rutas de autobús: la ruta en coche es la mejor aproximación disponible.
        request.transportType = .automobile

        let response = try await MKDirections(request: request).calculate()

        guard let route = response.routes.first else {
            throw RouteEstimationError.noRoute
        }

        return RouteEstimate(
            expectedTravelTime: route.expectedTravelTime,
            distance: route.distance,
            path: Self.path(from: route.polyline)
        )
    }

    private static func path(from polyline: MKPolyline) -> [RouteCoordinate] {
        var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))
        return coordinates.map { RouteCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
    }
}
