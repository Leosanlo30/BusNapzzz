//
//  RouteEstimate.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import CoreLocation // Necesario para usar CLLocationDistance

struct RouteEstimate: Sendable {
    
    let expectedTravelTime: TimeInterval
    let distance: CLLocationDistance
    
}

