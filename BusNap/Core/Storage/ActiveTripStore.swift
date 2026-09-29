//
//  ActiveTripStore.swift
//  BusNap
//

import Foundation

/// Snapshot persistente de un viaje en curso.
///
/// Permite que, si iOS termina la app y la relanza en segundo plano por una
/// geocerca, el `TripEngine` recupere el contexto (destino, tono, vibración)
/// en lugar de disparar una alarma "huérfana".
struct ActiveTrip: Codable, Equatable {
    let id: UUID
    let destination: Destination
    let leadTimeMinutes: Int
    let soundName: String
    let vibrate: Bool
    let startedAt: Date

    /// Identificador de la geocerca asociada. Usamos el UUID del viaje y no el
    /// nombre del destino: el nombre puede ser privado ("Casa") o cambiar.
    var regionIdentifier: String { "BusNap.trip.\(id.uuidString)" }
}

protocol ActiveTripStoring {
    func load() -> ActiveTrip?
    func save(_ trip: ActiveTrip)
    func clear()
}

struct UserDefaultsActiveTripStore: ActiveTripStoring {
    private let defaults: UserDefaults
    private let key = "com.busnap.app.activeTrip"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ActiveTrip? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ActiveTrip.self, from: data)
    }

    func save(_ trip: ActiveTrip) {
        guard let data = try? JSONEncoder().encode(trip) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
