//
//  LeadTimePickerView.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/07/26.
//

import Foundation
import SwiftUI

struct LeadTimePickerView: View {
    var viewModel: MapDashboardViewModel
    
    // Armamos las 3 opciones usando la estructura exacta de tu modelo actual
    let options: [AlertLeadTime] = [
        .threeMinutes,
        .fiveMinutes,
        .safeCustom(minutes: 10) // Usamos tu método seguro para generar una tercera opción
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Avisarme antes de llegar:")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppConstants.Colors.secondaryText)
            
            HStack(spacing: 12) {
                ForEach(options) { option in
                    // Verificamos cuál está seleccionado comparando los minutos
                    let isSelected = viewModel.leadTime.minutes == option.minutes
                    
                    Button(action: {
                        // Al usar tu función de intención, el ViewModel actualiza el estado
                        // y dispara el guardado en UserDefaults en la misma línea
                        viewModel.updateLeadTime(option)
                    }) {
                        Text(option.displayTitle)
                            .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity)
                            // Cambio de colores dinámico para Dark/Light mode
                            .background(isSelected ? AppConstants.Colors.primaryAccent : Color(UIColor.tertiarySystemFill))
                            .foregroundColor(isSelected ? .white : .primary)
                            .cornerRadius(10)
                    }
                    // Pequeña animación táctil
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
            }
        }
    }
}

#Preview {
    @MainActor in
    let mockVM = MapDashboardViewModel()
    return LeadTimePickerView(viewModel: mockVM)
        .padding()
}
