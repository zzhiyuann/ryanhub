import SwiftUI

/// Standard text input field with Ryan Hub design system styling.
/// hubSurfaceSecondary background, hubBorder stroke, cornerRadius 12.
struct HubTextField: View {
    @Environment(\.colorScheme) private var colorScheme
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(.hubBody)
        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
        .padding(.horizontal, HubLayout.standardPadding)
        .frame(height: HubLayout.buttonHeight)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.inputCornerRadius)
                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HubLayout.inputCornerRadius)
                .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        HubTextField(placeholder: "Enter text...", text: .constant(""))
        HubTextField(placeholder: "Password", text: .constant(""), isSecure: true)
    }
    .padding()
}
