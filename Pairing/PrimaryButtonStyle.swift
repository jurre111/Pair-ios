import SwiftUI

struct PrimaryBlueButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let background = backgroundColor(isPressed: configuration.isPressed, isEnabled: isEnabled)

        return configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(background, in: RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool, isEnabled: Bool) -> Color {
        if !isEnabled { return Color.blue.opacity(0.6) }
        return isPressed ? Color.blue.opacity(0.9) : Color.blue
    }
}
