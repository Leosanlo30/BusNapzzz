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
                    switch newPhase {
                    case .background:
                        print("[ENERGÍA] App en segundo plano: El usuario bloqueó la pantalla o salió.")
                        // Si tuvieras animaciones pesadas o cálculos de red cíclicos, aquí los pausas.
                        
                    case .active:
                        print("[ENERGÍA] App activa: El usuario volvió a abrir la app.")
                        // Aquí retomas los cálculos visuales si los habías pausado.
                        
                    case .inactive:
                        print("[ENERGÍA] App inactiva: (Ej. Bajó el centro de control o recibió una llamada)")
                        
                    @unknown default:
                        break
                    }
                }
        }
    }
}
