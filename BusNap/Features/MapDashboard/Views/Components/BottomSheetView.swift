//
//  BottomSheetView.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 09/07/26.
//

import Foundation
import SwiftUI

struct BottomSheetView: View {
    // Recibimos el ViewModel. Como usamos @Observable, SwiftUI
    // detectará automáticamente los cambios al leer estas variables.
    var viewModel: MapDashboardViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            
            //Título dinámico
            Text(viewModel.alarmStatus == .inactive ? "Configura tu Viaje" : "Monitoreando Viaje")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            //Información del destino
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(AppConstants.Colors.primaryAccent)
                
                if let destination = viewModel.selectedDestination {
                    Text(destination.name ?? "Destino seleccionado")
                        .fontWeight(.medium)
                } else {
                    Text("Selecciona un destino en el mapa")
                        .foregroundColor(AppConstants.Colors.secondaryText)
                }
                Spacer()
            }
            
            //ETA Simulado (Solo se muestra si existe)
            if let eta = viewModel.simulatedETA {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.green)
                    Text("Llegada en aprox. \(eta) min")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            
            // Botón de Acción Principal (Usando el que creamos en el Issue 1)
            if viewModel.alarmStatus == .inactive {
                PrimaryButton(title: "Activar Alarma") {
                    viewModel.activateTrip()
                }
                // Si no hay destino, bajamos la opacidad y bloqueamos el tap
                .opacity(viewModel.selectedDestination == nil ? 0.5 : 1.0)
                .disabled(viewModel.selectedDestination == nil)
                
            } else {
                PrimaryButton(title: "Cancelar Viaje") {
                    viewModel.cancelTrip()
                }
            }
        }
        .padding(AppConstants.Layout.standardPadding)
        .background(AppConstants.Colors.background)
        .cornerRadius(AppConstants.Layout.cornerRadius)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
    }
}

#Preview {
    // Creamos un ViewModel falso para el preview
    let mockViewModel = MapDashboardViewModel()
    // Descomenta la siguiente línea para ver cómo se ve con un destino asignado
    // mockViewModel.updateDestination(Destination(name: "Facultad de Matemáticas", latitude: 0, longitude: 0))
    
    return BottomSheetView(viewModel: mockViewModel)
        .padding()
        .background(Color.gray.opacity(0.3))
}
