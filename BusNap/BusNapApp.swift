//
//  BusNapApp.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 10/06/26.
//

import SwiftUI

@main
struct BusNapApp: App {
    
    @State private var viewModel = MapDashboardViewModel()
    
    // 1. Le pedimos a iOS que nos avise en qué estado se encuentra la pantalla
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            MapDashboardView(viewModel: viewModel)
                
                // 2. Escuchamos activamente cuando el estado cambie (iOS 17+)
                .onChange(of: scenePhase) { _, newPhase in
                    viewModel.handleScenePhase(newPhase)
                }
        }
    }
}
