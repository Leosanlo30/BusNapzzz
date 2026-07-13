//
//  MockRouteEstimator.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import CoreLocation
@testable import BusNap // Esto nos permite leer los modelos de la app principal

// Nuestro doble de acción. Es Sendable para cumplir con el contrato de concurrencia.
struct MockRouteEstimator: RouteEstimating {
    
    // Controles para manipular el resultado desde los tests
    var shouldFail: Bool = false
    var simulatedTime: TimeInterval = 900 // 15 minutos por defecto
    var simulatedDistance: CLLocationDistance = 5000 // 5 km por defecto
    
    func estimateRoute(to destination: Destination) async throws -> RouteEstimate {
        
        // Simulamos un retraso de red de medio segundo para probar el "isLoadingETA"
        try await Task.sleep(nanoseconds: 500_000_000)
        
        if shouldFail {
            throw RoutingError.routeNotFound
        }
        
        return RouteEstimate(
            expectedTravelTime: simulatedTime,
            distance: simulatedDistance
        )
    }
}
