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
    
    func estimateRoute(to destination: Destination, from currentLocation: CLLocation? = nil) async throws -> MKRoute {
        let request = MKDirections.Request()
        
        // 1. ORIGEN
        if let location = currentLocation {
           
            // Pasamos 'address: nil' ya que solo nos interesan las coordenadas puras.
            request.source = MKMapItem(location: location, address: nil)
        } else {
            request.source = MKMapItem.forCurrentLocation()
        }
        
        // 2. DESTINO
        // Convertimos tus coordenadas a un objeto CLLocation estándar
        let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        

        request.destination = MKMapItem(location: destLocation, address: nil)
        
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        
        guard let route = response.routes.first else {
            throw NSError(domain: "RouteError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Ruta no encontrada"])
        }
        
        return route
    }
}
