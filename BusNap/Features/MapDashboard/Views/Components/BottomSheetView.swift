import SwiftUI

struct BottomSheetView: View {
    @Bindable var viewModel: MapDashboardViewModel
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 16) {
            // Drag handle — indica que el sheet es interactivo
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.bottom, 4)

            headerRow
            destinationRow

            if let eta = viewModel.simulatedETA {
                etaRow(eta: eta)
            }

            if viewModel.alarmStatus == .inactive {
                leadTimeSelector
            }

            Divider()

            actionButton

            if viewModel.showDebugOverlay {
                debugSection
            }
        }
        .padding(AppConstants.Layout.standardPadding)
        .background(AppConstants.Colors.background)
        .cornerRadius(AppConstants.Layout.cornerRadius)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        .animation(.easeInOut(duration: 0.25), value: viewModel.alarmStatus)
        .sheet(isPresented: $showSettings) {
            TripSettingsSheet(viewModel: viewModel)
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text(headerTitle)
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            if viewModel.alarmStatus == .inactive {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundColor(AppConstants.Colors.secondaryText)
                }
            }
        }
    }

    private var headerTitle: String {
        switch viewModel.alarmStatus {
        case .inactive:                    return "Configura tu Viaje"
        case .configured, .monitoring:    return "Monitoreando Viaje"
        case .criticalZone:               return "Llegando al destino"
        case .triggered:                  return "¡Llegaste!"
        case .cancelled:                  return "Viaje Cancelado"
        }
    }

    // MARK: - Destination

    private var destinationRow: some View {
        HStack {
            Image(systemName: "mappin.and.ellipse")
                .foregroundColor(AppConstants.Colors.primaryAccent)
            if let destination = viewModel.selectedDestination {
                Text(destination.name ?? "Destino seleccionado")
                    .fontWeight(.medium)
            } else {
                Text("Toca el mapa para seleccionar destino")
                    .foregroundColor(AppConstants.Colors.secondaryText)
            }
            Spacer()
        }
    }

    // MARK: - ETA

    private func etaRow(eta: Int) -> some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(.green)
            Text("Llegada en aprox. \(eta) min")
                .fontWeight(.semibold)
            Spacer()
        }
    }

    // MARK: - Lead Time Chips

    private var leadTimeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Anticipación")
                .font(.caption)
                .foregroundColor(AppConstants.Colors.secondaryText)

            HStack(spacing: 8) {
                ForEach(AlertLeadTime.presets) { preset in
                    let isSelected = viewModel.leadTime == preset
                    Button { viewModel.updateLeadTime(preset) } label: {
                        Text(preset.displayTitle)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isSelected
                                ? AppConstants.Colors.primaryAccent
                                : AppConstants.Colors.secondaryBackground)
                            .foregroundColor(isSelected ? .white : AppConstants.Colors.primaryText)
                            .clipShape(Capsule())
                    }
                }

                if case .custom(let min) = viewModel.leadTime {
                    Text("\(min) min")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppConstants.Colors.primaryAccent)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }

                Spacer()
            }
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        switch viewModel.alarmStatus {
        case .inactive:
            PrimaryButton(title: "Activar Alarma") {
                viewModel.activateTrip()
            }
            .opacity(viewModel.selectedDestination == nil ? 0.5 : 1.0)
            .disabled(viewModel.selectedDestination == nil)

        case .configured, .monitoring, .criticalZone:
            PrimaryButton(title: "Cancelar Viaje") {
                viewModel.cancelTrip()
            }

        case .triggered:
            PrimaryButton(title: "Apagar Alarma") {
                viewModel.dismissAlarm()
            }

        case .cancelled:
            PrimaryButton(title: "Nuevo Viaje") {
                viewModel.cancelTrip()
            }
        }
    }

    // MARK: - Debug Overlay

    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            Text("DEBUG")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.orange)

            if let dest = viewModel.selectedDestination {
                Text("Lat: \(String(format: "%.4f", dest.latitude)) | Lon: \(String(format: "%.4f", dest.longitude))")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }

            Text("Status: \(viewModel.alarmStatus.rawValue)")
                .font(.caption2)
                .foregroundColor(.orange)

            Text("LeadTime: \(viewModel.leadTime.minutes) min | Vibrate: \(viewModel.vibrateEnabled ? "ON" : "OFF") | Tono: \(viewModel.selectedRingtone)")
                .font(.caption2)
                .foregroundColor(.orange)

            // Botón para simular que la alarma se disparó
            Button("⚡ Simular alarma disparada") {
                viewModel.alarmStatus = .triggered
            }
            .font(.caption2)
            .foregroundColor(.orange)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("Inactive") {
    BottomSheetView(viewModel: MapDashboardViewModel())
        .padding()
        .background(Color.gray.opacity(0.3))
}

#Preview("Monitoring") {
    let vm = MapDashboardViewModel()
    vm.updateDestination(Destination(name: "Facultad de Matemáticas", latitude: 21.0478, longitude: -89.6242))
    vm.activateTrip()
    return BottomSheetView(viewModel: vm)
        .padding()
        .background(Color.gray.opacity(0.3))
}

#Preview("Alarma Sonando") {
    let vm = MapDashboardViewModel()
    vm.updateDestination(Destination(name: "UADY", latitude: 21.0478, longitude: -89.6242))
    vm.activateTrip()
    vm.alarmStatus = .triggered
    return BottomSheetView(viewModel: vm)
        .padding()
        .background(Color.gray.opacity(0.3))
}

#Preview("Debug ON") {
    let vm = MapDashboardViewModel()
    vm.updateDestination(Destination(name: "Centro Histórico", latitude: 19.4326, longitude: -99.1332))
    vm.showDebugOverlay = true
    return BottomSheetView(viewModel: vm)
        .padding()
        .background(Color.gray.opacity(0.3))
}
