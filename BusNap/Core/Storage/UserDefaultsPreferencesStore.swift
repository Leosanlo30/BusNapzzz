//
//  UserDefaultsPreferencesStore.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation

struct UserDefaultsPreferencesStore: UserPreferencesStoring {
    private let leadTimeKey = "com.busnap.app.preferences.leadTime"
    
    func saveLeadTime(_ time: AlertLeadTime) {
        // Como tu enum tiene un valor asociado (.custom), lo convertimos a Data (JSON)
        if let encoded = try? JSONEncoder().encode(time) {
            UserDefaults.standard.set(encoded, forKey: leadTimeKey)
        }
    }
    
    func loadLeadTime() -> AlertLeadTime {
        // Leemos la Data guardada y la decodificamos de vuelta a tu Enum
        if let savedData = UserDefaults.standard.data(forKey: leadTimeKey),
           let decoded = try? JSONDecoder().decode(AlertLeadTime.self, from: savedData) {
            return decoded
        }
        
        // Si es la primera vez que el usuario abre la app o hay un error, retornamos tu preset por defecto
        return .fiveMinutes
    }
}
