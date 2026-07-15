import SwiftUI

let ringtoneOptions = ["Alarm", "Busy Bee", "Chime", "Gentle Wake", "Marimba"]

struct SettingsView: View {
    @Bindable var viewModel: MapDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                customTimeSection
                vibrationSection
                ringtoneSection
                themeSection
            }
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                        .buttonStyle(.hapticLight)
                }
            }
        }
    }

    // MARK: - Custom Time

    private var customTimeSection: some View {
        Section("Tiempo personalizado") {
            HStack {
                Text("Minutos de aviso")
                    .font(.subheadline)
                Spacer()
                Picker("Minutos", selection: $viewModel.customLeadTimeMinutes) {
                    ForEach(1...19, id: \.self) { minute in
                        Text("\(minute) min").tag(minute)
                    }
                }
                .pickerStyle(.menu)
            }

            Button(action: {
                let custom = AlertLeadTime.safeCustom(minutes: viewModel.customLeadTimeMinutes)
                viewModel.updateLeadTime(custom)
            }) {
                HStack {
                    Spacer()
                    Text("Usar como tiempo de aviso")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
            }
            .buttonStyle(.hapticLight)
        }
    }

    // MARK: - Vibration

    private var vibrationSection: some View {
        Section("Vibración") {
            Toggle(isOn: $viewModel.vibrationEnabled) {
                HStack {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .foregroundColor(AppConstants.Colors.primaryAccent)
                    Text("Vibración activa")
                }
            }
            .tint(AppConstants.Colors.primaryAccent)
        }
    }

    // MARK: - Ringtone

    private var ringtoneSection: some View {
        Section("Tono de alarma") {
            NavigationLink {
                RingtonePickerView(selectedRingtone: $viewModel.ringtoneName)
            } label: {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundColor(AppConstants.Colors.primaryAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tono")
                            .font(.subheadline)
                        Text(viewModel.ringtoneName)
                            .font(.caption)
                            .foregroundColor(AppConstants.Colors.secondaryText)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Themes

    private var themeSection: some View {
        Section("Tema") {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                Button(action: { viewModel.updateTheme(theme) }) {
                    HStack {
                        Image(systemName: theme.systemImage)
                            .foregroundColor(AppConstants.Colors.primaryAccent)
                            .frame(width: 28)

                        Text(theme.displayName)
                            .font(.subheadline)
                            .foregroundColor(AppConstants.Colors.primaryText)

                        Spacer()

                        if theme == viewModel.selectedTheme {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppConstants.Colors.primaryAccent)
                                .font(.subheadline)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            if viewModel.selectedTheme == .liquidGlass {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(AppConstants.Colors.secondaryText)
                    Text("Los paneles se vuelven translúcidos para mostrar el mapa detrás.")
                        .font(.caption)
                        .foregroundColor(AppConstants.Colors.secondaryText)
                }
            }
        }
    }
}

// MARK: - Ringtone Picker

struct RingtonePickerView: View {
    @Binding var selectedRingtone: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(ringtoneOptions, id: \.self) { tone in
            Button(action: {
                selectedRingtone = tone
                dismiss()
            }) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(AppConstants.Colors.primaryAccent)
                    Text(tone)
                        .font(.subheadline)
                        .foregroundColor(AppConstants.Colors.primaryText)
                    Spacer()
                    if tone == selectedRingtone {
                        Image(systemName: "checkmark")
                            .foregroundColor(AppConstants.Colors.primaryAccent)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Seleccionar tono")
        .navigationBarTitleDisplayMode(.inline)
    }
}
