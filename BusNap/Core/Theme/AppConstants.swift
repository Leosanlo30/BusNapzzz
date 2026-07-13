//
//  AppConstants.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 08/07/26.
//

import Foundation
import SwiftUI

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "Sistema"
    case light  = "Claro"
    case dark   = "Oscuro"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - App Constants

enum AppConstants {
    
    enum Colors{
        
        //Color principal
        static let primaryAccent = Color(UIColor.systemBlue)
        
        //Colores de fondo
        static let background = Color(UIColor.systemBackground)
        static let secondaryBackground = Color(UIColor.secondarySystemBackground)
        
        //Colores del texto
        
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        
    }
    
    enum Layout {
        static let cornerRadius: CGFloat    = 16.0
        static let standardPadding: CGFloat = 16.0
        static let buttonHeight: CGFloat    = 56.0
    }

    enum Ringtones {
        static let available = ["Default", "Chime", "Bell", "Alert", "Sonar"]
    }
}
