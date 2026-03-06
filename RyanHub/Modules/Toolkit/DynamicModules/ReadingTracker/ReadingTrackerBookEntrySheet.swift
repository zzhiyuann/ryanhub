import SwiftUI

struct ReadingTrackerBookEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let viewModel: ReadingTrackerViewModel
    var onSave: (() -> Void)?

    @State private var title: String = ""
    @State private var author: String = ""
    @State private var totalPages: Int = 300
    @State private var selectedGenre: BookGenre = .fiction
    @State private var selectedStatus: ReadingStatus = .wantToRead
    @State private var notes: String = ""

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !author.trimmingCharacters(in: .whitespaces).isEmpty &&
        totalPages > 0
    }

    var body: some View {
        QuickEntrySheet(
            title: "Add Book",
            icon: "plus.circle.fill",
            canSave: canSave,
            onSave: saveEntry
        ) {
            EntryFormSection(title: "Book Details") {
                HubTextField(placeholder: "Title", text: $title)
                HubTextField(placeholder: "Author", text: $author)
            }

            EntryFormSection(title: "Pages") {
                Stepper(value: $totalPages, in: 1...10000, step: 10) {
                    HStack {
                        Image(systemName: "doc.plaintext")
                            .foregroundStyle(Color.hubPrimary)
                        Text("\(totalPages) pages")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    }
                }
            }

            EntryFormSection(title: "Genre") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HubLayout.itemSpacing) {
                        ForEach(BookGenre.allCases) { genre in
                            genreChip(genre)
                        }
                    }
                }
            }

            EntryFormSection(title: "Status") {
                HStack(spacing: HubLayout.itemSpacing) {
                    statusButton(.wantToRead)
                    statusButton(.reading)
                }
            }

            EntryFormSection(title: "Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
                    .font(.hubBody)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(AdaptiveColors.surfaceSecondary(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius))
            }
        }
    }

    // MARK: - Genre Chip

    private func genreChip(_ genre: BookGenre) -> some View {
        let isSelected = selectedGenre == genre
        return Button {
            selectedGenre = genre
        } label: {
            HStack(spacing: 6) {
                Image(systemName: genre.icon)
                    .font(.caption)
                Text(genre.displayName)
                    .font(.hubCaption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.hubPrimary : AdaptiveColors.surfaceSecondary(for: colorScheme))
            .foregroundStyle(isSelected ? .white : AdaptiveColors.textSecondary(for: colorScheme))
            .clipShape(Capsule())
        }
    }

    // MARK: - Status Button

    private func statusButton(_ status: ReadingStatus) -> some View {
        let isSelected = selectedStatus == status
        return Button {
            selectedStatus = status
        } label: {
            HStack(spacing: 6) {
                Image(systemName: status.icon)
                Text(status.displayName)
                    .font(.hubBody)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.hubPrimary : AdaptiveColors.surfaceSecondary(for: colorScheme))
            .foregroundStyle(isSelected ? .white : AdaptiveColors.textSecondary(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius))
        }
    }

    // MARK: - Save

    private func saveEntry() {
        let now = Date()
        let entry = ReadingTrackerEntry(
            title: title.trimmingCharacters(in: .whitespaces),
            author: author.trimmingCharacters(in: .whitespaces),
            totalPages: totalPages,
            currentPage: 0,
            status: selectedStatus,
            genre: selectedGenre,
            rating: 0,
            notes: notes.trimmingCharacters(in: .whitespaces),
            startedReading: selectedStatus == .reading ? now : now,
            finishedReading: nil,
            lastReadDate: now
        )
        Task {
            await viewModel.addEntry(entry)
        }
        onSave?()
        dismiss()
    }
}