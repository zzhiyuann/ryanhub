import SwiftUI

/// Standard text input field with Cortex design system styling.
/// cortexSurfaceSecondary background, cortexBorder stroke, cornerRadius 12.
struct CortexTextField: View {
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
        .font(.cortexBody)
        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
        .padding(.horizontal, CortexLayout.standardPadding)
        .frame(height: CortexLayout.buttonHeight)
        .background(
            RoundedRectangle(cornerRadius: CortexLayout.inputCornerRadius)
                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CortexLayout.inputCornerRadius)
                .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        CortexTextField(placeholder: "Enter text...", text: .constant(""))
        CortexTextField(placeholder: "Password", text: .constant(""), isSecure: true)
    }
    .padding()
}
