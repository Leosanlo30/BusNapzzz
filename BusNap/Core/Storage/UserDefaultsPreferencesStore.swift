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
    private let themeKey = "com.busnap.app.preferences.theme"
    
    func saveLeadTime(_ time: AlertLeadTime) {
        if let encoded = try? JSONEncoder().encode(time) {
            UserDefaults.standard.set(encoded, forKey: leadTimeKey)
        }
    }
    
    func loadLeadTime() -> AlertLeadTime {
        if let savedData = UserDefaults.standard.data(forKey: leadTimeKey),
           let decoded = try? JSONDecoder().decode(AlertLeadTime.self, from: savedData) {
            return decoded
        }
        return .fiveMinutes
    }
    
    func saveFavorites(_ favorites: [Destination]) {
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: favoritesKey)
        }
    }
    
    func loadFavorites() -> [Destination] {
        if let savedData = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([Destination].self, from: savedData) {
            return decoded
        }
        return []
    }
    
    func saveTheme(_ theme: AppTheme) {
        UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
    }
    
    func loadTheme() -> AppTheme {
        guard let raw = UserDefaults.standard.string(forKey: themeKey),
              let theme = AppTheme(rawValue: raw) else {
            return .liquidGlass
        }
        return theme
    }
}
