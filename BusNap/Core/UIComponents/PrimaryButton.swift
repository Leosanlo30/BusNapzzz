//
//  PrimaryButton.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 08/07/26.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String // recibe un texto que sera el que se vea en el UI
    let action: () -> Void //retorna nada
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            Text(title)
                // Tipografía clara
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                
                // Comportamiento de expansión
                .frame(maxWidth: .infinity)
                .frame(height: AppConstants.Layout.buttonHeight)
                
                // Fondo y bordes redondeados usando constantes de AppConstants
                .background(AppConstants.Colors.primaryAccent)
                .cornerRadius(AppConstants.Layout.cornerRadius)
                
                // ligero sombreado
                .shadow(color: AppConstants.Colors.primaryAccent.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        // Este padding asegura que si el botón toca los bordes de la pantalla, respete un margen
        .padding(.horizontal, AppConstants.Layout.standardPadding)
    }
}

// Ver en al canvas (command + option + enter)
#Preview {
    VStack(spacing: 20) {
        PrimaryButton(title: "Activar Alarma") {
            print("Botón presionado")
        }
        
        PrimaryButton(title: "Cancelar Viaje") {
            print("Cancelar presionado")
        }
    }
}


