//
//  MapDashboardView.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 09/07/26.
//

import Foundation
import SwiftUI

@MainActor
struct MapDashboardView: View {
    
    var viewModel: MapDashboardViewModel
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // 1. Mapa real e interactivo (El fondo)
            DestinationMapView(viewModel: viewModel)
            
            // 2. Banner visual OFFLINE (¡Corregido!)
            // Ahora el 'if' envuelve al VStack entero. Si hay internet,
            // esta capa simplemente deja de existir y permite los toques.
            if viewModel.isOffline {
                VStack {
                    HStack {
                        Image(systemName: "wifi.slash")
                        Text("Sin conexión a internet. Las estimaciones de ruta podrían fallar.")
                            .font(.footnote)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer() // Empuja el banner hacia arriba
                }
                .animation(.easeInOut, value: viewModel.isOffline)
                .zIndex(1)
            }
            
            // 3. Bottom Sheet (La capa superior)
            BottomSheetView(viewModel: viewModel)
                .padding(.horizontal, AppConstants.Layout.standardPadding)
                .padding(.bottom, 32)
                .zIndex(2)
        }
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    @MainActor in
    let mockVM = MapDashboardViewModel()
    return MapDashboardView(viewModel: mockVM)
}
