import Foundation
import SwiftUI

struct BottomSheetView: View {
    var viewModel: MapDashboardViewModel
    
    // Propiedad computada para saber si estamos en estado de "espera de usuario"
    var isWaitingForUser: Bool {
        viewModel.alarmStatus == .idle || viewModel.alarmStatus == .configured
    }
    
    var body: some View {
        VStack(spacing: 16) {
            
            // 1. Título dinámico
            Text(isWaitingForUser ? "Configura tu Viaje" : "Monitoreando Viaje")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 2. Información del destino
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
            
            // 3. Selector de tiempo (Solo si no estamos monitoreando)
            if isWaitingForUser {
                LeadTimePickerView(viewModel: viewModel)
                    .padding(.top, 4)
                
                Button("🎵 Probar Altavoz") {
                    AudioManager.shared.playAlarm()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        AudioManager.shared.stopAlarm()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.top, 2)
            }
            
            // 4. Bloque de Advertencias Críticas (Se queda en medio si ocurren errores)
            VStack(spacing: 12) {
                if viewModel.permissionState == .denied || viewModel.permissionState == .restricted {
                    WarningBanner(
                        icon: "location.slash.fill",
                        message: "GPS denegado. Ve a Configuración de iOS para permitir el acceso."
                    )
                } else if viewModel.permissionState == .authorizedWhenInUse && !isWaitingForUser {
                    WarningBanner(
                        icon: "exclamationmark.shield.fill",
                        message: "¡Cuidado! Si bloqueas la pantalla, la alarma podría no sonar. Otorga permiso 'Siempre'."
                    )
                }
                
                if viewModel.isOffline {
                    WarningBanner(
                        icon: "wifi.slash",
                        message: "Sin conexión. El cálculo podría fallar."
                    )
                }
                
                if let error = viewModel.errorMessage {
                    WarningBanner(icon: "exclamationmark.triangle.fill", message: error)
                }
            }
            
            // 5. ¡MOVIDO AQUÍ! Información del Tiempo Real Vial (Justo arriba del botón)
            Group {
                if viewModel.isLoadingETA {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Calculando ruta...")
                            .foregroundColor(AppConstants.Colors.secondaryText)
                            .fontWeight(.medium)
                        Spacer()
                    }
                } else if let eta = viewModel.simulatedETA {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.green)
                        
                        let minutes = max(1, Int(ceil(eta / 60)))
                        
                        Text("Tiempo de ruta: \(minutes) min")
                            .fontWeight(.semibold)
                            .foregroundColor(minutes <= viewModel.leadTime.minutes ? .red : .primary)
                        
                        Spacer()
                    }
                }
            }
            .padding(.top, 4) // Pequeña separación estética antes de llegar al botón
            
            // 6. Botón de Acción Principal
            if isWaitingForUser {
                PrimaryButton(title: "Activar Alarma") {
                    viewModel.activateTrip()
                }
                .opacity(viewModel.selectedDestination == nil || viewModel.isLoadingETA || viewModel.permissionState == .denied ? 0.5 : 1.0)
                .disabled(viewModel.selectedDestination == nil || viewModel.isLoadingETA || viewModel.permissionState == .denied)
                
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
    
    // MARK: - Subvistas

    struct WarningBanner: View {
        let icon: String
        let message: String
        
        var body: some View {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.red)
                Text(message)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                Spacer()
            }
        }
    }
}
