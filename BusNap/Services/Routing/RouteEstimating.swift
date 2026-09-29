//
//  RouteEstimating.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import CoreLocation

//Protocolo para decir como interactuar con las rutas
protocol RouteEstimating: Sendable {
    func estimateRoute(to destination: Destination, from currentLocation: CLLocation?, mode: TravelMode) async throws -> RouteEstimate
}

extension RouteEstimating {
    func estimateRoute(to destination: Destination, from currentLocation: CLLocation?) async throws -> RouteEstimate {
        try await estimateRoute(to: destination, from: currentLocation, mode: .transit)
    }
}
