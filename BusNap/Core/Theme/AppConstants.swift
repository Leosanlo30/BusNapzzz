//
//  AppConstants.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 08/07/26.
//

import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Codable, Sendable {
    case light
    case dark
    case liquidGlass

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .liquidGlass: return "Liquid Glass"
        }
    }

    var systemImage: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .liquidGlass: return "drop.fill"
        }
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
