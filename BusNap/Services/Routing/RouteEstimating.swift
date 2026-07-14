//
//  RouteEstimating.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import MapKit
import CoreLocation

//Protocolo para decir como interactuar con las rutas
protocol RouteEstimating: Sendable {
    func estimateRoute(to destination: Destination, from currentLocation: CLLocation?) async throws -> MKRoute
}
