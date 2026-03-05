import SwiftUI

struct ReadingTrackerEntrySheet: View {
    let viewModel: ReadingTrackerViewModel
    var onSave: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var bookTitle: String = ""
    @State private var author: String = ""
    @State private var genre: BookGenre = .fiction
    @State private var status: ReadingStatus = .reading
    @State private var pagesRead: Int = 0
    @State private var currentPage: Int = 0
    @State private var totalPages: Int = 0
    @State private var readingMinutes: Int = 0
    @State private var rating: Double = 0.0
    @State private var notes: String = ""
    @State private var entryDate: Date = Date()

    private var canSave: Bool {
        !bookTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        QuickEntrySheet(
            title: "Add Reading Tracker",
            icon: "plus.circle.fill",
            canSave: canSave,
            onSave: {
                saveEntry()
            }
        ) {
            EntryFormSection(title: "Book Info") {
                TextField("Book Title", text: $bookTitle)
                    .textFieldStyle(.plain)
                    .padding(HubLayout.standardPadding)
                    .background(AdaptiveColors.background(for: colorScheme).opacity(0.5))
                    .cornerRadius(10)

                TextField("Author", text: $author)
                    .textFieldStyle(.plain)
                    .padding(HubLayout.standardPadding)
                    .background(AdaptiveColors.background(for: colorScheme).opacity(0.5))
                    .cornerRadius(10)

                Picker("Genre", selection: $genre) {
                    ForEach(BookGenre.allCases) { g in
                        Label(g.displayName, systemImage: g.icon).tag(g)
                    }
                }
                .pickerStyle(.menu)

                Picker("Status", selection: $status) {
                    ForEach(ReadingStatus.allCases) { s in
                        Label(s.displayName, systemImage: s.icon).tag(s)
                    }
                }
                .pickerStyle(.menu)
            }

            EntryFormSection(title: "Reading Session") {
                Stepper("Pages Read: \(pagesRead)", value: $pagesRead, in: 0...9999, step: 5)
                Stepper("Minutes Read: \(readingMinutes)", value: $readingMinutes, in: 0...480, step: 5)
            }

            EntryFormSection(title: "Progress") {
                Stepper("Current Page: \(currentPage)", value: $currentPage, in: 0...9999)
                Stepper("Total Pages: \(totalPages)", value: $totalPages, in: 0...9999, step: 10)

                if totalPages > 0 {
                    let progress = min(1.0, Double(currentPage) / Double(totalPages))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Progress")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            Spacer()
                            Text("\(currentPage)/\(totalPages) (\(Int(progress * 100))%)")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                        ProgressView(value: progress)
                            .tint(Color.hubPrimary)
                    }
                }
            }

            EntryFormSection(title: "Rating") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Rating")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Spacer()
                        Text(rating >= 1.0 ? String(format: "%.1f ★", rating) : "Unrated")
                            .font(.hubCaption)
                            .foregroundStyle(rating >= 1.0 ? Color.hubAccentYellow : AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    Slider(value: $rating, in: 0...10, step: 0.5)
                        .tint(Color.hubAccentYellow)
                }
            }

            EntryFormSection(title: "Notes") {
                TextField("Add notes...", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...6)
                    .padding(HubLayout.standardPadding)
                    .background(AdaptiveColors.background(for: colorScheme).opacity(0.5))
                    .cornerRadius(10)
            }

            EntryFormSection(title: "Date") {
                DatePicker("Entry Date", selection: $entryDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
            }
        }
    }

    private func saveEntry() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        var entry = ReadingTrackerEntry()
        entry.bookTitle = bookTitle.trimmingCharacters(in: .whitespaces)
        entry.author = author.trimmingCharacters(in: .whitespaces)
        entry.genre = genre
        entry.status = status
        entry.pagesRead = pagesRead
        entry.currentPage = currentPage
        entry.totalPages = totalPages
        entry.readingMinutes = readingMinutes
        entry.rating = rating
        entry.notes = notes.trimmingCharacters(in: .whitespaces)
        entry.date = formatter.string(from: entryDate)

        Task { await viewModel.addEntry(entry) }
        onSave?()
    }
}