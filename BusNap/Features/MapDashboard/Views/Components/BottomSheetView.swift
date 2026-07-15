import Foundation
import SwiftUI

struct BottomSheetView: View {
    @Bindable var viewModel: MapDashboardViewModel
    
    @FocusState private var isNameFocused: Bool
    
    var isWaitingForUser: Bool {
        viewModel.alarmStatus == .idle || viewModel.alarmStatus == .configured
    }
    
    var body: some View {
        VStack(spacing: 16) {
            
            // 1. Header: close button + title
            HStack {
                if !isWaitingForUser {
                    Button(action: { viewModel.cancelTrip() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(isWaitingForUser ? "Coloco pin" : "Viaje iniciado")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                if isWaitingForUser, viewModel.selectedDestination != nil {
                    Button(action: { viewModel.saveAsFavorite() }) {
                        Image(systemName: viewModel.savedFavorites.contains(where: { $0.latitude == viewModel.selectedDestination?.latitude && $0.longitude == viewModel.selectedDestination?.longitude }) ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundColor(AppConstants.Colors.primaryAccent)
                    }
                }
            }
            
            if isWaitingForUser {
                // 2. Nombre de ubicación
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(AppConstants.Colors.primaryAccent)
                    TextField("Nombre ubicación", text: $viewModel.destinationName)
                        .fontWeight(.medium)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit { viewModel.confirmDestinationName() }
                    if !viewModel.destinationName.isEmpty {
                        Button(action: {
                            viewModel.destinationName = ""
                            viewModel.confirmDestinationName()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(UIColor.tertiarySystemFill))
                .cornerRadius(10)
                
                // 3. Tiempo de ruta
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
                
                // 4. Lead time picker
                LeadTimePickerView(viewModel: viewModel)
                
                // 5. Test speaker
                Button(action: {
                    AudioManager.shared.playAlarm()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        AudioManager.shared.stopAlarm()
                    }
                }) {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                        Text("Probar Altavoz")
                            .font(.caption)
                    }
                    .foregroundColor(AppConstants.Colors.primaryAccent)
                }
                
                // 6. Favorites
                if !viewModel.savedFavorites.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.savedFavorites, id: \.self) { fav in
                                Button(action: { viewModel.selectFavorite(fav) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "heart.fill")
                                            .font(.caption2)
                                        Text(fav.name ?? "Favorito")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(AppConstants.Colors.primaryAccent.opacity(0.15))
                                    .foregroundColor(AppConstants.Colors.primaryAccent)
                                    .cornerRadius(16)
                                }
                            }
                        }
                    }
                }
                
                // 7. Action button
                PrimaryButton(title: "Activar Alarma") {
                    viewModel.confirmDestinationName()
                    viewModel.activateTrip()
                }
                .opacity(viewModel.selectedDestination == nil || viewModel.isLoadingETA || viewModel.permissionState == .denied ? 0.5 : 1.0)
                .disabled(viewModel.selectedDestination == nil || viewModel.isLoadingETA || viewModel.permissionState == .denied)
                
            } else {
                // 2. Monitoring state: nombre + info
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(AppConstants.Colors.primaryAccent)
                    if let destination = viewModel.selectedDestination {
                        Text(destination.name ?? "Destino seleccionado")
                            .fontWeight(.medium)
                    }
                    Spacer()
                }
                
                // 3. Tiempo de ruta (actualizable durante el viaje)
                Group {
                    if viewModel.isLoadingETA {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Actualizando ruta...")
                                .foregroundColor(AppConstants.Colors.secondaryText)
                            Spacer()
                        }
                    } else if let eta = viewModel.simulatedETA {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.green)
                            let minutes = max(1, Int(ceil(eta / 60)))
                            Text("Tiempo de viaje: \(minutes) min")
                                .fontWeight(.semibold)
                                .foregroundColor(minutes <= viewModel.leadTime.minutes ? .red : .primary)
                            Spacer()
                        }
                    }
                }
                
                // 4. Advertencias
                VStack(spacing: 12) {
                    if viewModel.permissionState == .denied || viewModel.permissionState == .restricted {
                        WarningBanner(icon: "location.slash.fill", message: "GPS denegado. Ve a Configuración de iOS para permitir el acceso.")
                    } else if viewModel.permissionState == .authorizedWhenInUse {
                        WarningBanner(icon: "exclamationmark.shield.fill", message: "¡Cuidado! Si bloqueas la pantalla, la alarma podría no sonar. Otorga permiso 'Siempre'.")
                    }
                    if viewModel.isOffline {
                        WarningBanner(icon: "wifi.slash", message: "Sin conexión. El cálculo podría fallar.")
                    }
                    if let error = viewModel.errorMessage {
                        WarningBanner(icon: "exclamationmark.triangle.fill", message: error)
                    }
                }
                
                // 5. Cancel button
                PrimaryButton(title: "Cancelar Viaje") {
                    viewModel.cancelTrip()
                }
            }
        }
        .padding(AppConstants.Layout.standardPadding)
        .background(AppConstants.Colors.background)
        .cornerRadius(AppConstants.Layout.cornerRadius)
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: -4)
        .alert("Nombre del destino", isPresented: $viewModel.showNameAlert) {
            TextField("Nombre", text: $viewModel.destinationName)
            Button("Guardar") { viewModel.confirmDestinationName() }
            Button("Cancelar", role: .cancel) { viewModel.showNameAlert = false }
        } message: {
            Text("Escribe un nombre para este destino")
        }
    }
    
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
