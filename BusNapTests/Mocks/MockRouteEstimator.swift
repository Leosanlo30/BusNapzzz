//
//  MockRouteEstimator.swift
//  BusNapTests
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import CoreLocation
@testable import BusNap

// Nuestro doble de acción. Es Sendable para cumplir con el contrato de concurrencia.
struct MockRouteEstimator: RouteEstimating {
    
    var shouldFail: Bool = false
    var simulatedTime: TimeInterval = 900
    var simulatedDistance: CLLocationDistance = 5000
    
    func estimateRoute(to destination: Destination, from currentLocation: CLLocation?) async throws -> RouteEstimate {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        if shouldFail {
            throw NSError(domain: "MockRouteEstimator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Route not found"])
        }
        
        return RouteEstimate(expectedTravelTime: simulatedTime, distance: simulatedDistance)
    }
}
