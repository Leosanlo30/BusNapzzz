import SwiftUI

struct Ringtone: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let filename: String
}

let ringtones: [Ringtone] = [
    Ringtone(name: "Alarm", filename: "alarm"),
    Ringtone(name: "Alarm 2", filename: "alarm2"),
    Ringtone(name: "Alarm 3", filename: "alarm3"),
]

struct SettingsView: View {
    @Bindable var viewModel: MapDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                customTimeSection
                vibrationSection
                ringtoneSection
            }
            .listStyle(.insetGrouped)
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
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(AppConstants.Colors.primaryAccent)
                    Text("Minutos de aviso")
                        .font(.subheadline)
                    Spacer()
                    Text("\(viewModel.customLeadTimeMinutes) min")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppConstants.Colors.primaryAccent)
                }

                Stepper("", value: $viewModel.customLeadTimeMinutes, in: 1...19)
                    .labelsHidden()
            }

            Button(action: {
                let custom = AlertLeadTime.safeCustom(minutes: viewModel.customLeadTimeMinutes)
                viewModel.updateLeadTime(custom)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                    Image(systemName: "bell.fill")
                        .foregroundColor(AppConstants.Colors.primaryAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tono")
                            .font(.subheadline)
                        Text(ringtones.first(where: { $0.filename == viewModel.ringtoneName })?.name ?? viewModel.ringtoneName)
                            .font(.caption)
                            .foregroundColor(AppConstants.Colors.secondaryText)
                    }
                    Spacer()
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
        List(ringtones) { tone in
            Button(action: {
                selectedRingtone = tone.filename
                dismiss()
            }) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(AppConstants.Colors.primaryAccent)
                    Text(tone.name)
                        .font(.subheadline)
                        .foregroundColor(AppConstants.Colors.primaryText)
                    Spacer()
                    if tone.filename == selectedRingtone {
                        Image(systemName: "checkmark")
                            .foregroundColor(AppConstants.Colors.primaryAccent)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Seleccionar tono")
        .navigationBarTitleDisplayMode(.inline)
    }
}
