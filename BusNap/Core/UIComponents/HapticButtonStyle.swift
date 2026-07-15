import SwiftUI

struct HapticButtonStyle: ButtonStyle {
    let feedback: UIImpactFeedbackGenerator.FeedbackStyle

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: feedback).impactOccurred()
                }
            }
    }
}

extension ButtonStyle where Self == HapticButtonStyle {
    static var hapticLight: HapticButtonStyle { HapticButtonStyle(feedback: .light) }
    static var hapticMedium: HapticButtonStyle { HapticButtonStyle(feedback: .medium) }
    static var hapticHeavy: HapticButtonStyle { HapticButtonStyle(feedback: .heavy) }
}
