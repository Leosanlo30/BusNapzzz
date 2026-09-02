import SwiftUI

struct LeadTimePickerView: View {
    @Environment(ThemeManager.self) private var theme
    var viewModel: MapDashboardViewModel

    private var options: [AlertLeadTime] {
        [
            .threeMinutes,
            .fiveMinutes,
            .safeCustom(minutes: viewModel.customLeadTimeMinutes)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Avisarme antes de llegar:")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(options, id: \.id) { option in
                    let isSelected = viewModel.leadTime.minutes == option.minutes

                    Button(action: {
                        viewModel.updateLeadTime(option)
                    }) {
                        Text(option.displayTitle)
                            .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(AppConstants.Colors.primaryAccent)
                                        .shadow(color: AppConstants.Colors.primaryAccent.opacity(0.3), radius: 6, x: 0, y: 3)
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.white.opacity(theme.mode == .liquidGlass ? 0.15 : 0), lineWidth: 1)
                                }
                            }
                            .innerClearContainer(cornerRadius: 12)
                    }
                    .buttonStyle(.hapticLight)
                    .animation(.busnapSpring, value: isSelected)
                }
            }
        }
    }
}
