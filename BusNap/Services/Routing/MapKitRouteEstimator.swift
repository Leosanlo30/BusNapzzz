//
//  MapKitRouteEstimator.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import MapKit

// manejador de errores personalizado
enum RoutingError: Error, LocalizedError {
    case routeNotFound
    case networkFailure(Error)
    
    var errorDescription: String? {
        switch self {
        case .routeNotFound:
            return "No se encontró una ruta disponible hacia el destino seleccionado."
        case .networkFailure(let error):
            return "Error de red al calcular la ruta: \(error.localizedDescription)"
        }
    }
}

struct MapKitRouteEstimator: RouteEstimating {
    
    //funcion de estimar ruta
    func estimateRoute(to destination: Destination) async throws -> RouteEstimate {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        
        let destinationLocation = CLLocation(
            latitude: destination.latitude,
            longitude: destination.longitude
        )
        
        // pasamos la direccion: nil para cumplir con el contrato estricto de iOS 26+
        let destinationItem = MKMapItem(location: destinationLocation, address: nil)
        destinationItem.name = destination.name ?? "Destino"
        
        request.destination = destinationItem
        request.transportType = .automobile // usamoss automobile debido a que Mapkit no tiene rutas de merida
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            
            guard let primaryRoute = response.routes.first else {
                throw RoutingError.routeNotFound
            }
            
            //retorna la tura estimada con sus atributost
            return RouteEstimate(
                expectedTravelTime: primaryRoute.expectedTravelTime,
                distance: primaryRoute.distance
            )
            
        } catch let error as RoutingError {
            throw error
        } catch {
            throw RoutingError.networkFailure(error)
        }
    }
}
