import SwiftUI

/// Section header label with Cortex design system styling.
/// cortexTextSecondary color, cortexCaption font, uppercased text.
struct SectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.cortexCaption)
            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 24) {
        SectionHeader(title: "General")
        SectionHeader(title: "Appearance")
    }
    .padding()
}
