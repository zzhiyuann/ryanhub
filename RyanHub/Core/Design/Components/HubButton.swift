import SwiftUI

/// Primary action button with Ryan Hub design system styling.
/// hubPrimary background, white text, cornerRadius 12, height 48.
struct HubButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: HubLayout.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                    .fill(Color.hubPrimary)
            )
        }
        .disabled(isLoading)
    }
}

/// Secondary (outlined) button variant.
struct HubSecondaryButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let icon: String?
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.hubPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: HubLayout.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                    .stroke(Color.hubPrimary, lineWidth: 1.5)
            )
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HubButton("Primary Action", icon: "arrow.right") {}
        HubButton("Loading...", isLoading: true) {}
        HubSecondaryButton("Secondary", icon: "gear") {}
    }
    .padding()
}
