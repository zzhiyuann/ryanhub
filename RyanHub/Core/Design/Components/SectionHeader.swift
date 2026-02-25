import SwiftUI

/// Section header label with Ryan Hub design system styling.
/// hubTextSecondary color, hubCaption font, uppercased text.
struct SectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.hubCaption)
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
