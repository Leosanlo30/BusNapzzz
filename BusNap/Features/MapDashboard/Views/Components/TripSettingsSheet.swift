import SwiftUI

struct TripSettingsSheet: View {
    @Bindable var viewModel: MapDashboardViewModel
    @State private var customMinutes: Int = 10
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                anticipationSection
                alarmSection
                appearanceSection
                developerSection
            }
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if case .custom(let min) = viewModel.leadTime {
                customMinutes = min
            }
        }
        .preferredColorScheme(viewModel.appTheme.colorScheme)
    }

    // MARK: - Anticipación

    private var anticipationSection: some View {
        Section {
            ForEach(AlertLeadTime.presets) { preset in
                Button {
                    viewModel.updateLeadTime(preset)
                } label: {
                    HStack {
                        Text(preset.displayTitle)
                            .foregroundColor(.primary)
                        Spacer()
                        if viewModel.leadTime == preset {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppConstants.Colors.primaryAccent)
                        }
                    }
                }
            }

            Stepper("\(customMinutes) min antes", value: $customMinutes, in: 1...60)

            Button {
                viewModel.updateLeadTime(.safeCustom(minutes: customMinutes))
            } label: {
                HStack {
                    Text("Guardar \(customMinutes) min")
                        .fontWeight(.semibold)
                    Spacer()
                    if case .custom(let min) = viewModel.leadTime, min == customMinutes {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .foregroundColor(AppConstants.Colors.primaryAccent)

        } header: {
            Text("Anticipación de Alarma")
        } footer: {
            Text("Minutos antes de llegar al destino para activar la alarma.")
        }
    }

    // MARK: - Alarma

    private var alarmSection: some View {
        Section("Alarma") {
            Toggle("Vibración", isOn: $viewModel.vibrateEnabled)

            Picker("Tono", selection: $viewModel.selectedRingtone) {
                ForEach(AppConstants.Ringtones.available, id: \.self) { tone in
                    Text(tone)
                }
            }
        }
    }

    // MARK: - Apariencia

    private var appearanceSection: some View {
        Section("Apariencia") {
            Picker("Tema", selection: $viewModel.appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Desarrollador

    private var developerSection: some View {
        Section {
            Toggle("Overlay de debug", isOn: $viewModel.showDebugOverlay)
        } header: {
            Text("Desarrollador")
        } footer: {
            Text("Muestra coordenadas y estado técnico del viaje activo.")
        }
    }
}

// MARK: - Preview

#Preview {
    TripSettingsSheet(viewModel: MapDashboardViewModel())
}
