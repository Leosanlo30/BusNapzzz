import SwiftUI

struct Ringtone: Identifiable, Hashable {
    var id: String { filename }
    let name: String
    let filename: String
}

let ringtones: [Ringtone] = [
    Ringtone(name: "Clásica", filename: "alarm"),
    Ringtone(name: "Pulso", filename: "alarm2"),
    Ringtone(name: "Amanecer", filename: "alarm3"),
]

struct SettingsView: View {
    @Bindable var viewModel: MapDashboardViewModel
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var settings = viewModel.settings

        NavigationStack {
            Form {
                alarmSection(settings: settings)
                mapSection(settings: settings)
                permissionsSection
                appearanceSection
                aboutSection
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
        .onDisappear { AudioManager.shared.stopPreview() }
    }

    // MARK: - Alarm

    private func alarmSection(settings: AppSettings) -> some View {
        @Bindable var settings = settings

        return Section {
            NavigationLink {
                RingtonePickerView(selectedRingtone: $settings.ringtoneName)
            } label: {
                SettingsRow("Tono", icon: "bell.fill", color: .red) {
                    Text(ringtones.first { $0.filename == settings.ringtoneName }?.name ?? settings.ringtoneName)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $settings.vibrationEnabled) {
                SettingsLabel("Vibración", icon: "iphone.radiowaves.left.and.right", color: .pink)
            }

            Stepper(value: $settings.customLeadTimeMinutes, in: 1...19) {
                SettingsRow("Aviso personalizado", icon: "timer", color: .orange) {
                    Text("\(settings.customLeadTimeMinutes) min")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: settings.customLeadTimeMinutes) { _, minutes in
                // Si el aviso personalizado está en uso, se actualiza al momento.
                if case .custom = viewModel.leadTime {
                    viewModel.updateLeadTime(.safeCustom(minutes: minutes))
                }
            }

            Button {
                AudioManager.shared.previewSound(named: settings.ringtoneName, vibrate: settings.vibrationEnabled)
            } label: {
                SettingsLabel("Probar alarma", icon: "play.fill", color: .green)
            }
            .disabled(viewModel.isTripActive)
        } header: {
            Text("Alarma")
        } footer: {
            Text("El tono suena aunque el iPhone esté en modo silencio. Sube el volumen antes de dormirte.")
        }
    }

    // MARK: - Map

    private func mapSection(settings: AppSettings) -> some View {
        @Bindable var settings = settings

        return Section {
            Picker(selection: $settings.mapStyle) {
                ForEach(MapStyleOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            } label: {
                SettingsLabel("Tipo de mapa", icon: "map.fill", color: .blue)
            }

            Toggle(isOn: $settings.showsTransitStops) {
                SettingsLabel("Paradas de transporte", icon: "bus.fill", color: .indigo)
            }

            Toggle(isOn: $settings.showsTraffic) {
                SettingsLabel("Tráfico", icon: "car.2.fill", color: .orange)
            }

            Toggle(isOn: $settings.showsRealisticElevation) {
                SettingsLabel("Edificios en 3D", icon: "building.2.fill", color: .gray)
            }

            Toggle(isOn: $settings.followsUserDuringTrip) {
                SettingsLabel("Seguir mi ubicación en el viaje", icon: "location.fill", color: .blue)
            }

            Picker(selection: $settings.distanceUnit) {
                ForEach(DistanceUnit.allCases) { unit in
                    Text(unit.label).tag(unit)
                }
            } label: {
                SettingsLabel("Distancias", icon: "ruler.fill", color: .teal)
            }
        } header: {
            Text("Mapa")
        }
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        Section {
            SettingsRow("Ubicación", icon: "location.fill", color: .blue) {
                PermissionBadge(isOK: viewModel.permissionState == .authorizedAlways,
                                text: locationPermissionText)
            }

            SettingsRow("Notificaciones", icon: "bell.badge.fill", color: .red) {
                PermissionBadge(isOK: viewModel.notificationPermission == .authorized,
                                text: notificationPermissionText)
            }

            if let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Abrir Ajustes de iOS") { openURL(url) }
            }
        } header: {
            Text("Permisos")
        } footer: {
            Text("Para despertarte con la pantalla bloqueada, BusNap necesita la ubicación en \"Siempre\" y las notificaciones activadas.")
        }
    }

    private var locationPermissionText: String {
        switch viewModel.permissionState {
        case .authorizedAlways: "Siempre"
        case .authorizedWhenInUse: "Solo al usar"
        case .denied: "Denegada"
        case .restricted: "Restringida"
        case .notDetermined: "Sin configurar"
        }
    }

    private var notificationPermissionText: String {
        switch viewModel.notificationPermission {
        case .authorized: "Activadas"
        case .denied: "Desactivadas"
        case .notDetermined: "Sin configurar"
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section("Apariencia") {
            Picker(selection: Binding(
                get: { theme.mode },
                set: { theme.mode = $0 }
            )) {
                ForEach(AppThemeMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.icon).tag(mode)
                }
            } label: {
                SettingsLabel("Tema", icon: "paintbrush.fill", color: .purple)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent("Versión", value: appVersion)
        } footer: {
            Text("El tiempo estimado usa rutas en coche de Apple Maps como aproximación del recorrido del autobús.")
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}

// MARK: - Components

/// Etiqueta con icono en cuadro de color, al estilo de la app Ajustes.
private struct SettingsLabel: View {
    let title: String
    let icon: String
    let color: Color

    init(_ title: String, icon: String, color: Color) {
        self.title = title
        self.icon = icon
        self.color = color
    }

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}

/// Fila con etiqueta a la izquierda y valor a la derecha.
private struct SettingsRow<Value: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let value: Value

    init(_ title: String, icon: String, color: Color, @ViewBuilder value: () -> Value) {
        self.title = title
        self.icon = icon
        self.color = color
        self.value = value()
    }

    var body: some View {
        HStack {
            SettingsLabel(title, icon: icon, color: color)
            Spacer(minLength: 8)
            value
        }
    }
}

private struct PermissionBadge: View {
    let isOK: Bool
    let text: String

    var body: some View {
        Label(text, systemImage: isOK ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .foregroundStyle(isOK ? AppConstants.Colors.success : AppConstants.Colors.warning)
            .font(.subheadline)
    }
}

// MARK: - Ringtone Picker

struct RingtonePickerView: View {
    @Binding var selectedRingtone: String

    var body: some View {
        List(ringtones) { tone in
            Button {
                selectedRingtone = tone.filename
                AudioManager.shared.previewSound(named: tone.filename)
            } label: {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundStyle(AppConstants.Colors.primaryAccent)
                    Text(tone.name)
                        .foregroundStyle(.primary)
                    Spacer()
                    if tone.filename == selectedRingtone {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(AppConstants.Colors.primaryAccent)
                    }
                }
            }
        }
        .navigationTitle("Tono de alarma")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { AudioManager.shared.stopPreview() }
    }
}
