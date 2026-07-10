//
//  MapDashboardView.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 09/07/26.
//

import Foundation
import SwiftUI

struct MapDashboardView: View {
    @State private var viewModel = MapDashboardViewModel()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // 1. Nuestro mapa real e interactivo (El fondo)
            DestinationMapView(viewModel: viewModel)
            
            // 2. Nuestro Bottom Sheet (La capa superior)
            BottomSheetView(viewModel: viewModel)
                .padding(.horizontal, AppConstants.Layout.standardPadding)
                // Le damos un pequeño margen extra en la parte inferior para respirar
                .padding(.bottom, 32)
        }
    }
}

#Preview {
    MapDashboardView()
}
