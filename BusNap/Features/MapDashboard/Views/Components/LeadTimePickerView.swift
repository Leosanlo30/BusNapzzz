import SwiftUI

struct LeadTimePickerView: View {
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
                .foregroundColor(AppConstants.Colors.secondaryText)

            HStack(spacing: 12) {
                ForEach(options, id: \.id) { option in
                    let isSelected = viewModel.leadTime.minutes == option.minutes

                    Button(action: {
                        viewModel.updateLeadTime(option)
                    }) {
                        Text(option.displayTitle)
                            .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                isSelected
                                    ? AnyShapeStyle(AppConstants.Colors.primaryAccent)
                                    : AnyShapeStyle(Material.ultraThinMaterial),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .foregroundColor(isSelected ? .white : .primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: isSelected ? 0 : 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
            }
        }
    }
}
