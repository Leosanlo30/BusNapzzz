//
//  AppSettings.swift
//  BusNap
//

import Foundation
import Observation

// MARK: - Map Options

/// Tipo de mapa, al estilo del selector de Apple Maps, adaptado a BusNap.
enum MapStyleOption: String, CaseIterable, Identifiable {
    /// Mapa estándar con puntos de interés.
    case standard
    /// Mapa atenuado que resalta paradas y estaciones de transporte público.
    case transit
    /// Satélite con calles y etiquetas.
    case hybrid
    /// Solo imágenes de satélite.
    case satellite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: "Explorar"
        case .transit: "Transporte"
        case .hybrid: "Híbrido"
        case .satellite: "Satélite"
        }
    }

    var icon: String {
        switch self {
        case .standard: "map"
        case .transit: "bus"
        case .hybrid: "globe.americas"
        case .satellite: "globe.americas.fill"
        }
    }
}

/// Unidades para mostrar distancias.
enum DistanceUnit: String, CaseIterable, Identifiable {
    case automatic
    case kilometers
    case miles

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic: "Automático"
        case .kilometers: "Kilómetros"
        case .miles: "Millas"
        }
    }
}

// MARK: - AppSettings

/// Única fuente de verdad para las preferencias del usuario.
///
/// Reemplaza la mezcla anterior de `@AppStorage`, `UserDefaults.standard` y
/// propiedades sueltas en el ViewModel. Cada cambio se persiste de inmediato.
/// Las claves heredadas (`vibrationEnabled`, `ringtoneName`, `customLeadTime`)
/// se mantienen para no perder las preferencias de instalaciones existentes.
@MainActor
@Observable
final class AppSettings {

    // MARK: Alarma

    var ringtoneName: String { didSet { defaults.set(ringtoneName, forKey: Keys.ringtone) } }
    var vibrationEnabled: Bool { didSet { defaults.set(vibrationEnabled, forKey: Keys.vibration) } }
    var customLeadTimeMinutes: Int { didSet { defaults.set(customLeadTimeMinutes, forKey: Keys.customLeadTime) } }

    // MARK: Ruta

    /// Cómo viaja el usuario: define el cálculo de la ruta y el radio de alarma.
    var travelMode: TravelMode { didSet { defaults.set(travelMode.rawValue, forKey: Keys.travelMode) } }

    // MARK: Mapa

    var mapStyle: MapStyleOption { didSet { defaults.set(mapStyle.rawValue, forKey: Keys.mapStyle) } }
    var showsTraffic: Bool { didSet { defaults.set(showsTraffic, forKey: Keys.traffic) } }
    var showsTransitStops: Bool { didSet { defaults.set(showsTransitStops, forKey: Keys.transitStops) } }
    var showsRealisticElevation: Bool { didSet { defaults.set(showsRealisticElevation, forKey: Keys.elevation) } }
    var followsUserDuringTrip: Bool { didSet { defaults.set(followsUserDuringTrip, forKey: Keys.follow) } }
    var distanceUnit: DistanceUnit { didSet { defaults.set(distanceUnit.rawValue, forKey: Keys.distanceUnit) } }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ringtoneName = defaults.string(forKey: Keys.ringtone) ?? "alarm"
        vibrationEnabled = defaults.object(forKey: Keys.vibration) as? Bool ?? true
        customLeadTimeMinutes = defaults.object(forKey: Keys.customLeadTime) as? Int ?? 10
        travelMode = defaults.string(forKey: Keys.travelMode).flatMap(TravelMode.init) ?? .transit
        mapStyle = defaults.string(forKey: Keys.mapStyle).flatMap(MapStyleOption.init) ?? .standard
        showsTraffic = defaults.object(forKey: Keys.traffic) as? Bool ?? false
        showsTransitStops = defaults.object(forKey: Keys.transitStops) as? Bool ?? true
        showsRealisticElevation = defaults.object(forKey: Keys.elevation) as? Bool ?? false
        followsUserDuringTrip = defaults.object(forKey: Keys.follow) as? Bool ?? true
        distanceUnit = defaults.string(forKey: Keys.distanceUnit).flatMap(DistanceUnit.init) ?? .automatic
    }

    /// Formatea una distancia respetando la unidad elegida.
    func formattedDistance(_ meters: Double) -> String {
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        switch distanceUnit {
        case .automatic:
            return measurement.formatted(.measurement(width: .abbreviated, usage: .road))
        case .kilometers:
            let unit: UnitLength = meters < 1_000 ? .meters : .kilometers
            return measurement.converted(to: unit)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                        numberFormatStyle: .number.precision(.fractionLength(0...1))))
        case .miles:
            let unit: UnitLength = meters < 300 ? .feet : .miles
            return measurement.converted(to: unit)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                        numberFormatStyle: .number.precision(.fractionLength(0...1))))
        }
    }

    private enum Keys {
        static let ringtone = "ringtoneName"
        static let vibration = "vibrationEnabled"
        static let customLeadTime = "customLeadTime"
        static let travelMode = "busnap.route.travelMode"
        static let mapStyle = "busnap.map.style"
        static let traffic = "busnap.map.traffic"
        static let transitStops = "busnap.map.transitStops"
        static let elevation = "busnap.map.realisticElevation"
        static let follow = "busnap.map.followUser"
        static let distanceUnit = "busnap.distanceUnit"
    }
}
