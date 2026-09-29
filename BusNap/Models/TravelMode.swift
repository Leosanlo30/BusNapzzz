//
//  TravelMode.swift
//  BusNap
//

import MapKit

/// Forma de viajar hacia el destino. Determina cómo se calcula la ruta y
/// el tamaño de la zona de alarma (a más velocidad, más anticipación).
enum TravelMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case automobile
    case transit
    case walking

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automobile: "Coche"
        case .transit: "Transporte público"
        case .walking: "A pie"
        }
    }

    var shortLabel: String {
        switch self {
        case .automobile: "Coche"
        case .transit: "Transporte"
        case .walking: "A pie"
        }
    }

    var icon: String {
        switch self {
        case .automobile: "car.fill"
        case .transit: "bus.fill"
        case .walking: "figure.walk"
        }
    }

    /// Velocidad media urbana estimada, en m/s.
    var averageSpeed: CLLocationSpeed {
        switch self {
        case .automobile: 8.3  // ≈ 30 km/h en ciudad
        case .transit: 5.5     // ≈ 20 km/h autobús con paradas
        case .walking: 1.4     // ≈ 5 km/h
        }
    }

    /// Radio mínimo de la geocerca. A pie basta un radio menor; en vehículo
    /// iOS necesita margen para detectar la entrada a tiempo.
    var minimumAlarmRadius: CLLocationDistance {
        switch self {
        case .automobile, .transit: 500
        case .walking: 200
        }
    }

    var mapKitTransportType: MKDirectionsTransportType {
        switch self {
        case .automobile: .automobile
        case .transit: .transit
        case .walking: .walking
        }
    }
}
