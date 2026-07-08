//
//  AppConstants.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 08/07/26.
//

import Foundation
import SwiftUI


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
    
    //Medidas del Layout
    enum Layout{
        
        static let cornerRadius: CGFloat = 16.0
        static let standardPadding: CGFloat = 16.0
        static let buttonHeight: CGFloat = 56.0
        
        
    }
    
}
