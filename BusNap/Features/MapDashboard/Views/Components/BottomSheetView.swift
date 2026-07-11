import SwiftUI

struct BottomSheetView: View {
    let viewModel: MapDashboardViewModel

    var body: some View {
        VStack(spacing: AppConstants.Layout.standardPadding) {
            // Handle
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 4)

            // Status
            infoRow(label: "Estado", value: viewModel.alarmStatus.displayStatus)

            // Destination (only when set)
            if let destination = viewModel.selectedDestination {
                let label = destination.name ?? "\(destination.latitude), \(destination.longitude)"
                infoRow(label: "Destino", value: label)
            }

            // ETA (only when monitoring)
            if let eta = viewModel.simulatedETA {
                infoRow(label: "ETA", value: "\(eta) min", valueColor: AppConstants.Colors.primaryAccent)
            }

            Divider()

            // Action button — conditional on alarm state
            if viewModel.alarmStatus == .inactive {
                PrimaryButton(title: "Activar Alarma") {
                    viewModel.activateTrip()
                }
            } else {
                PrimaryButton(title: "Cancelar Viaje") {
                    viewModel.cancelTrip()
                }
            }
        }
        .padding(AppConstants.Layout.standardPadding)
        .background(AppConstants.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cornerRadius))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -4)
        .padding(.horizontal, AppConstants.Layout.standardPadding)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func infoRow(label: String, value: String, valueColor: Color = AppConstants.Colors.primaryText) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - Previews

#Preview("Inactive — no destination") {
    ZStack(alignment: .bottom) {
        Color(UIColor.systemGray5).ignoresSafeArea()
        BottomSheetView(viewModel: MapDashboardViewModel())
    }
}

#Preview("Monitoring — trip active") {
    let vm = MapDashboardViewModel()
    vm.updateDestination(Destination(name: "CDMX Centro", latitude: 19.4326, longitude: -99.1332))
    vm.activateTrip()
    return ZStack(alignment: .bottom) {
        Color(UIColor.systemGray5).ignoresSafeArea()
        BottomSheetView(viewModel: vm)
    }
}
