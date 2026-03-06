import SwiftUI

struct ReadingTrackerBookDetailView: View {
    let viewModel: ReadingTrackerViewModel
    let entry: ReadingTrackerEntry

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage: Int
    @State private var notes: String
    @State private var selectedStatus: ReadingStatus
    @State private var rating: Int
    @State private var showDeleteConfirmation = false
    @State private var isSaving = false

    init(viewModel: ReadingTrackerViewModel, entry: ReadingTrackerEntry) {
        self.viewModel = viewModel
        self.entry = entry
        _currentPage = State(initialValue: entry.currentPage)
        _notes = State(initialValue: entry.notes)
        _selectedStatus = State(initialValue: entry.status)
        _rating = State(initialValue: entry.rating)
    }

    private var hasChanges: Bool {
        currentPage != entry.currentPage ||
        notes != entry.notes ||
        selectedStatus != entry.status ||
        rating != entry.rating
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                headerSection
                progressSection
                notesSection
                statusSection
                if selectedStatus == .finished {
                    ratingSection
                }
                datesSection
                actionsSection
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, 40)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if hasChanges {
                    Button {
                        saveChanges()
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.hubPrimary)
                    }
                    .disabled(isSaving)
                }
            }
        }
        .alert("Delete Book", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteEntry(entry)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to remove \"\(entry.title)\" from your library? This cannot be undone.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(genreGradient)
                .frame(height: 180)
                .overlay(
                    VStack(spacing: HubLayout.itemSpacing) {
                        Image(systemName: entry.genre.icon)
                            .font(.system(size: 36))
                            .foregroundStyle(.white.opacity(0.9))

                        Text(entry.title)
                            .font(.hubHeading)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)

                        Text(entry.author)
                            .font(.hubBody)
                            .foregroundStyle(.white.opacity(0.8))

                        HStack(spacing: 6) {
                            Image(systemName: entry.status.icon)
                                .font(.caption)
                            Text(entry.status.displayName)
                                .font(.hubCaption)
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .padding(HubLayout.standardPadding)
                )
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                SectionHeader(title: "Progress")

                let fraction = entry.totalPages > 0
                    ? Double(currentPage) / Double(entry.totalPages)
                    : 0

                HStack {
                    Text("\(currentPage)")
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    Text("of \(entry.totalPages) pages")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    Spacer()
                    Text("\(Int(fraction * 100))%")
                        .font(.hubCaption)
                        .foregroundStyle(Color.hubPrimary)
                        .fontWeight(.semibold)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.hubPrimary.opacity(0.15))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(genreColor)
                            .frame(width: geo.size.width * min(max(fraction, 0), 1), height: 8)
                    }
                }
                .frame(height: 8)

                // Page stepper
                HStack(spacing: HubLayout.itemSpacing) {
                    Button {
                        if currentPage > 0 {
                            currentPage -= 1
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(currentPage > 0 ? Color.hubPrimary : Color.hubPrimary.opacity(0.3))
                    }
                    .disabled(currentPage <= 0)

                    Slider(
                        value: Binding(
                            get: { Double(currentPage) },
                            set: { currentPage = Int($0) }
                        ),
                        in: 0...Double(max(entry.totalPages, 1)),
                        step: 1
                    )
                    .tint(genreColor)

                    Button {
                        if currentPage < entry.totalPages {
                            currentPage += 1
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(currentPage < entry.totalPages ? Color.hubPrimary : Color.hubPrimary.opacity(0.3))
                    }
                    .disabled(currentPage >= entry.totalPages)
                }

                Text("\(entry.totalPages - currentPage) pages remaining")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        HubCard {
            VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                SectionHeader(title: "Notes")

                TextEditor(text: $notes)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 150, maxHeight: 300)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AdaptiveColors.background(for: colorScheme))
                    )
                    .overlay(
                        Group {
                            if notes.isEmpty {
                                Text("Quotes, thoughts, chapter notes...")
                                    .font(.hubBody)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.6))
                                    .padding(.leading, 13)
                                    .padding(.top, 16)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
            }
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        HubCard {
            VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                SectionHeader(title: "Status")

                HStack(spacing: 8) {
                    ForEach(ReadingStatus.allCases) { status in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedStatus = status
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: status.icon)
                                    .font(.system(size: 16))
                                Text(status.displayName)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedStatus == status
                                          ? statusColor(for: status).opacity(0.15)
                                          : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedStatus == status
                                            ? statusColor(for: status)
                                            : Color.clear, lineWidth: 1.5)
                            )
                            .foregroundStyle(selectedStatus == status
                                             ? statusColor(for: status)
                                             : AdaptiveColors.textSecondary(for: colorScheme))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Rating

    private var ratingSection: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                SectionHeader(title: "Rating")

                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                rating = rating == star ? 0 : star
                            }
                        } label: {
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(star <= rating ? Color.hubAccentYellow : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4))
                                .scaleEffect(star <= rating ? 1.1 : 1.0)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    if rating > 0 {
                        Text("\(rating)/5")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
            }
        }
    }

    // MARK: - Dates

    private var datesSection: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                SectionHeader(title: "Timeline")

                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Started")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            Text(entry.formattedStartDate)
                                .font(.hubBody)
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        }
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color.hubPrimary)
                    }

                    Spacer()

                    if let finishDate = entry.formattedFinishDate {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Finished")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text(finishDate)
                                    .font(.hubBody)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            }
                        } icon: {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(Color.hubAccentGreen)
                        }
                    }
                }

                HStack {
                    Label {
                        Text("\(entry.daysReading) days reading")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    Spacer()
                    Text("Last read \(entry.formattedLastRead)")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            if hasChanges {
                HubButton(isSaving ? "Saving..." : "Save Changes") {
                    saveChanges()
                }
                .disabled(isSaving)
            }

            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Book")
                }
                .font(.hubBody)
                .foregroundStyle(Color.hubAccentRed)
                .frame(maxWidth: .infinity)
                .frame(height: HubLayout.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                        .stroke(Color.hubAccentRed.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func saveChanges() {
        isSaving = true
        var updated = entry
        updated.currentPage = min(max(currentPage, 0), entry.totalPages)
        updated.notes = notes
        updated.status = selectedStatus
        updated.rating = rating
        updated.lastReadDate = Date()

        if selectedStatus == .finished && entry.status != .finished {
            updated.finishedReading = Date()
            updated.currentPage = entry.totalPages
            currentPage = entry.totalPages
        }
        if selectedStatus == .reading && entry.status == .wantToRead {
            updated.startedReading = Date()
        }

        Task {
            await viewModel.updateEntry(updated)
            isSaving = false
            dismiss()
        }
    }

    private var genreColor: Color {
        let colors: [Color] = [
            .hubPrimary, Color.hubAccentGreen, .cyan, .purple,
            Color.hubAccentRed, .orange, Color.hubAccentYellow,
            .brown, .teal, .indigo, .gray
        ]
        let index = entry.genreColorIndex
        return colors[index % colors.count]
    }

    private var genreGradient: LinearGradient {
        LinearGradient(
            colors: [genreColor, genreColor.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func statusColor(for status: ReadingStatus) -> Color {
        switch status {
        case .wantToRead: return Color.hubAccentYellow
        case .reading: return Color.hubPrimary
        case .finished: return Color.hubAccentGreen
        case .abandoned: return Color.hubAccentRed
        }
    }
}