import SwiftUI

// MARK: - Fluent Vocabulary Detail View

/// Detail sheet for a single vocabulary item.
/// Shows term, definition, Chinese translation, examples with TTS,
/// usage notes, and related terms.
struct FluentVocabularyDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let item: VocabularyItem
    let viewModel: FluentViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HubLayout.sectionSpacing) {
                    // Term header
                    termHeader

                    // Definition
                    definitionSection

                    // Examples
                    if !item.examples.isEmpty {
                        examplesSection
                    }

                    // Usage notes
                    if let notes = item.usageNotes {
                        usageNotesSection(notes)
                    }

                    // Related terms
                    if let related = item.relatedTerms, !related.isEmpty {
                        relatedTermsSection(related)
                    }
                }
                .padding(.horizontal, HubLayout.standardPadding)
                .padding(.vertical, HubLayout.sectionSpacing)
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.hubPrimary)
                }
            }
        }
    }

    // MARK: - Term Header

    private var termHeader: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            HStack(alignment: .center, spacing: 12) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(Color.hubPrimary.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: item.category.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.category.rawValue)
                        .font(.hubCaption)
                        .foregroundStyle(Color.hubPrimary)

                    Text(item.term)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }

                Spacer()

                // TTS button
                Button {
                    viewModel.speak(item.term)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color.hubPrimary.opacity(0.12))
                        )
                }
            }
        }
    }

    // MARK: - Definition Section

    private var definitionSection: some View {
        HubCard {
            VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                SectionHeader(title: "Definition")

                Text(item.definition)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let zh = item.chineseDefinition, viewModel.settings.showChinese {
                    Divider()
                        .background(AdaptiveColors.border(for: colorScheme))

                    HStack(spacing: 8) {
                        Text("CN")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.hubPrimary)
                            )

                        Text(zh)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.hubPrimary.opacity(0.9))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Examples Section

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Examples")

            ForEach(Array(item.examples.enumerated()), id: \.offset) { index, example in
                HubCard {
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.hubPrimary)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle().fill(Color.hubPrimary.opacity(0.12))
                            )

                        Text(example)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            .lineSpacing(3)
                            .italic()

                        Spacer()

                        Button {
                            viewModel.speak(example)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.hubPrimary)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle().fill(Color.hubPrimary.opacity(0.12))
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Usage Notes Section

    private func usageNotesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Usage Notes")

            HubCard {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.hubAccentYellow)

                    Text(notes)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Related Terms Section

    private func relatedTermsSection(_ terms: [String]) -> some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Related Terms")

            FlowLayout(spacing: 8) {
                ForEach(terms, id: \.self) { term in
                    Text(term)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.hubPrimary.opacity(0.12))
                        )
                }
            }
        }
    }
}

// MARK: - Flow Layout

/// Simple flow layout that wraps items to the next line when they exceed the width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return ArrangeResult(
            positions: positions,
            size: CGSize(width: maxX, height: currentY + lineHeight)
        )
    }
}
