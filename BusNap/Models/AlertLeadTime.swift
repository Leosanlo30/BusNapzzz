//
//  AlertLeadTime.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 22/06/26.
//

import Foundation


//nuevo tipo de dato
enum AlertLeadTime: Codable, Equatable, Identifiable {
    case threeMinutes
    case fiveMinutes
    case custom(minutes: Int)
    
    /// Factory method that clamps the provided minutes to the inclusive range 1...19.
    @inlinable
    static func safeCustom(minutes: Int) -> AlertLeadTime {
        // En Swift, max() y min() son funciones globales excelentes para "clamping"
        let clampedMinutes = max(1, min(minutes, 19))
        return .custom(minutes: clampedMinutes)
    }
    
    var id: String {
        switch self {
        case .threeMinutes: return "preset_3"
        case .fiveMinutes: return "preset_5"
        case .custom(let minutes): return "custom_\(minutes)"
        }
    }
    
    @inlinable
    var minutes: Int {
        switch self {
        case .threeMinutes: return 3
        case .fiveMinutes: return 5
        case .custom(let minutes): return minutes
        }
    }
    
    var displayTitle: String {
        switch self {
        case .custom(let minutes):
            return "Personalizado (\(minutes) min)"
        default:
            return "\(minutes) minutos antes"
        }
    }
    
    var inSeconds: TimeInterval {
        return TimeInterval(self.minutes * 60)
    }
    
    // 2. Actualizamos los presets para la UI
    static var presets: [AlertLeadTime] {
        return [.threeMinutes, .fiveMinutes]
    }
}

