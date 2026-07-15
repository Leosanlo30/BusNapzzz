import SwiftUI

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.headline)
                }
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppConstants.Layout.buttonHeight)
            .background(AppConstants.Colors.primaryAccent)
            .cornerRadius(AppConstants.Layout.cornerRadius)
            .shadow(color: AppConstants.Colors.primaryAccent.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PrimaryButton(title: "Iniciar Viaje", icon: "arrow.triangle.turn.up.right.circle.fill") {
            print("Start")
        }
        PrimaryButton(title: "Cancelar Viaje") {
            print("Cancel")
        }
    }
    .padding()
}
