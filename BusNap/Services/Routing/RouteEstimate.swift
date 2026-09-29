//
//  RouteEstimate.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import CoreLocation

/// Coordenada `Sendable` para transportar la geometría de la ruta entre actores.
struct RouteCoordinate: Sendable, Equatable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct RouteEstimate: Sendable {
    let expectedTravelTime: TimeInterval
    let distance: CLLocationDistance
    /// Geometría de la ruta para dibujarla en el mapa. Vacía si no está disponible.
    var path: [RouteCoordinate] = []
}
