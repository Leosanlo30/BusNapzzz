//
//  UserDefaultsPreferencesStore.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation

struct UserDefaultsPreferencesStore: UserPreferencesStoring {
    private let leadTimeKey = "com.busnap.app.preferences.leadTime"
    private let favoritesKey = "com.busnap.app.preferences.favorites"
    private let recentsKey = "com.busnap.app.preferences.recents"

    func saveLeadTime(_ time: AlertLeadTime) {
        save(time, forKey: leadTimeKey)
    }

    func loadLeadTime() -> AlertLeadTime {
        load(AlertLeadTime.self, forKey: leadTimeKey) ?? .fiveMinutes
    }

    func saveFavorites(_ favorites: [Destination]) {
        save(favorites, forKey: favoritesKey)
    }

    func loadFavorites() -> [Destination] {
        load([Destination].self, forKey: favoritesKey) ?? []
    }

    func saveRecents(_ recents: [Destination]) {
        save(recents, forKey: recentsKey)
    }

    func loadRecents() -> [Destination] {
        load([Destination].self, forKey: recentsKey) ?? []
    }

    // MARK: - Private

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        if let encoded = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
