//
//  ContentView.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/06/26.
//

import SwiftUI

struct ContentView: View {
    // Recibimos el ViewModel desde BusNapApp
    var viewModel: MapDashboardViewModel
    
    var body: some View {
        // Se lo pasamos a nuestra vista principal
        MapDashboardView(viewModel: viewModel)
    }
}

#Preview {
    @MainActor in
    let mockVM = MapDashboardViewModel()
    return ContentView(viewModel: mockVM)
}
