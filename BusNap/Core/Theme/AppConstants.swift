//
//  AppConstants.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 08/07/26.
//

import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Codable, Sendable, Identifiable {
    var id: String { rawValue }
    case system
    case light
    case dark
    case liquidGlass

    // MARK: - Propiedades de visualización

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .liquidGlass: return "Liquid Glass"
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "gearshape"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .liquidGlass: return "drop.fill"
        }
    }

    // MARK: - Fondos para tarjetas

    /// Fondo de las tarjetas según el tema activo.
    /// - Liquid Glass: .thinMaterial (alta transparencia para efecto vidrio)
    /// - Dark: negro puro (true black OLED)
    /// - Otros: fondo secundario del sistema
    var cardBackgroundStyle: AnyShapeStyle {
        switch self {
        case .liquidGlass:
            AnyShapeStyle(Material.thinMaterial)
        case .dark:
            AnyShapeStyle(Color.black)
        default:
            AnyShapeStyle(Color(UIColor.secondarySystemBackground))
        }
    }

    // MARK: - Bordes para efecto vidrio

    /// Color del borde reflectante para tarjetas Liquid Glass.
    /// En vidrio se usa blanco semitransparente para simular el reflejo del bisel.
    var cardBorderColor: Color {
        self == .liquidGlass ? .white.opacity(0.3) : .primary.opacity(0.1)
    }

    /// Grosor del borde reflectante.
    var cardBorderWidth: CGFloat {
        self == .liquidGlass ? 1 : 0.5
    }
}

enum AppConstants {
    
    enum Colors {
        
        static let primaryAccent = Color.accentColor
        
        static let background = Color(UIColor.systemBackground)
        static let secondaryBackground = Color(UIColor.secondarySystemBackground)
        
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary

        static let success = Color.green
        static let warning = Color.orange
        static let destructive = Color.red
        
    }
    
    enum Layout {
        
        static let cornerRadius: CGFloat = 16.0
        static let standardPadding: CGFloat = 16.0
        static let buttonHeight: CGFloat = 56.0
        static let smallButtonHeight: CGFloat = 44.0
        
    }
    
}
