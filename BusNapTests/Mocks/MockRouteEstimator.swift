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
    var delay: Duration = .milliseconds(50)
    /// Tiempos distintos por nombre de destino, para detectar respuestas cruzadas.
    var timesByDestinationName: [String: TimeInterval] = [:]
    /// Retrasos distintos por nombre de destino, para simular carreras.
    var delaysByDestinationName: [String: Duration] = [:]

    func estimateRoute(to destination: Destination, from currentLocation: CLLocation?) async throws -> RouteEstimate {
        try await Task.sleep(for: delaysByDestinationName[destination.name ?? ""] ?? delay)

        if shouldFail {
            throw NSError(domain: "MockRouteEstimator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Route not found"])
        }

        let time = timesByDestinationName[destination.name ?? ""] ?? simulatedTime
        return RouteEstimate(expectedTravelTime: time, distance: simulatedDistance)
    }
}
