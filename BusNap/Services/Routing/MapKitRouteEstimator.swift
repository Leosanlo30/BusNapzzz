//
//  MapKitRouteEstimator.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import MapKit
import CoreLocation

class MapKitRouteEstimator: RouteEstimating {
    
    func estimateRoute(to destination: Destination, from currentLocation: CLLocation? = nil) async throws -> RouteEstimate {
        let request = MKDirections.Request()
        
        if let location = currentLocation {
            request.source = MKMapItem(location: location, address: nil)
        } else {
            request.source = MKMapItem.forCurrentLocation()
        }
        
        let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        request.destination = MKMapItem(location: destLocation, address: nil)
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        
        guard let route = response.routes.first else {
            throw NSError(domain: "RouteError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Ruta no encontrada"])
        }
        
        return RouteEstimate(expectedTravelTime: route.expectedTravelTime, distance: route.distance)
    }
}
