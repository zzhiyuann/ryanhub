import SwiftUI

// MARK: - Fluent Vocabulary View

/// Vocabulary browser with search, category filtering, and word cards.
/// Tapping a word card opens a detail sheet.
struct FluentVocabularyView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: FluentViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
                .padding(.horizontal, HubLayout.standardPadding)
                .padding(.top, 8)

            // Category filter
            categoryFilter
                .padding(.top, 8)

            // Vocabulary list
            ScrollView {
                LazyVStack(spacing: HubLayout.itemSpacing) {
                    ForEach(viewModel.filteredVocabulary) { item in
                        vocabularyCard(item)
                    }
                }
                .padding(.horizontal, HubLayout.standardPadding)
                .padding(.vertical, HubLayout.itemSpacing)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            TextField("Search vocabulary...", text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.searchText = $0 }
            ))
            .font(.hubBody)
            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
        )
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All categories pill
                categoryPill(title: "All", icon: nil, isSelected: viewModel.selectedCategory == nil) {
                    viewModel.selectedCategory = nil
                }

                ForEach(VocabCategory.allCases) { category in
                    categoryPill(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, HubLayout.standardPadding)
        }
    }

    private func categoryPill(title: String, icon: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(
                isSelected
                    ? Color.white
                    : AdaptiveColors.textSecondary(for: colorScheme)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(
                        isSelected
                            ? Color.hubPrimary
                            : AdaptiveColors.surfaceSecondary(for: colorScheme)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Vocabulary Card

    private func vocabularyCard(_ item: VocabularyItem) -> some View {
        Button {
            viewModel.showDetail(for: item)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(item.term)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        // Category badge
                        Text(item.category.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.hubPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.hubPrimary.opacity(0.12))
                            )
                    }

                    Text(item.definition)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .lineLimit(2)

                    if let zh = item.chineseDefinition, viewModel.settings.showChinese {
                        Text(zh)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.hubPrimary.opacity(0.7))
                    }
                }

                Spacer()

                // TTS button
                Button {
                    viewModel.speak(item.term)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(Color.hubPrimary.opacity(0.12))
                        )
                }
            }
            .padding(HubLayout.cardInnerPadding)
            .background(
                RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                    .fill(AdaptiveColors.surface(for: colorScheme))
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.3)
                            : Color.black.opacity(0.06),
                        radius: 8, x: 0, y: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
