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
    /// `true` si el tiempo es una aproximación (p. ej. no hay datos de
    /// transporte público en la zona y se estimó a partir de la ruta en coche).
    var isApproximate: Bool = false
}
