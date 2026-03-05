import SwiftUI

// MARK: - Quick Entry Sheet

/// A modal sheet wrapper for fast data entry with consistent styling.
/// Provides title bar, save/cancel buttons, and dismiss-on-save behavior.
struct QuickEntrySheet<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let title: String
    let icon: String
    let saveLabel: String
    let canSave: Bool
    let onSave: () -> Void
    let content: () -> Content

    init(
        title: String,
        icon: String = "plus.circle.fill",
        saveLabel: String = "Save",
        canSave: Bool = true,
        onSave: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.saveLabel = saveLabel
        self.canSave = canSave
        self.onSave = onSave
        self.content = content
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HubLayout.sectionSpacing) {
                    content()
                }
                .padding(HubLayout.standardPadding)
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: icon)
                                .font(.system(size: 14))
                            Text(saveLabel)
                        }
                    }
                    .disabled(!canSave)
                    .foregroundStyle(canSave ? Color.hubPrimary : AdaptiveColors.textSecondary(for: colorScheme))
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Entry Form Section

/// A labeled section within a QuickEntrySheet.
struct EntryFormSection<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            content()
                .padding(HubLayout.cardInnerPadding)
                .background(
                    RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                        .fill(AdaptiveColors.surface(for: colorScheme))
                )
        }
    }
}

// MARK: - Quick Entry FAB

/// A floating action button for triggering quick entry.
struct QuickEntryFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.hubPrimary)
                        .shadow(color: Color.hubPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
                )
        }
    }
}
