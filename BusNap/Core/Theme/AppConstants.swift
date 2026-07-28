//
//  AppConstants.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 08/07/26.
//

import SwiftUI

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
