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
                ForEach(options) { option in
                    let isSelected = viewModel.leadTime.minutes == option.minutes

                    Button(action: {
                        viewModel.updateLeadTime(option)
                    }) {
                        Text(option.displayTitle)
                            .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity)
                            .background(isSelected ? AppConstants.Colors.primaryAccent : Color(UIColor.tertiarySystemFill))
                            .foregroundColor(isSelected ? .white : .primary)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
            }
        }
    }
}

#Preview {
    @MainActor in
    let mockVM = MapDashboardViewModel()
    return LeadTimePickerView(viewModel: mockVM)
        .padding()
}
