import SwiftUI

struct ReadingTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ReadingTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputBooktitle: String = ""
    @State private var inputAuthor: String = ""
    @State private var selectedGenre: BookGenre = .fiction
    @State private var selectedStatus: ReadingStatus = .wantToRead
    @State private var inputTotalpages: Int = 1
    @State private var inputCurrentpage: Int = 1
    @State private var inputMinutesread: Int = 1
    @State private var inputRating: Double = 5
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Reading Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = ReadingTrackerEntry(bookTitle: inputBooktitle, author: inputAuthor, genre: selectedGenre, status: selectedStatus, totalPages: inputTotalpages, currentPage: inputCurrentpage, minutesRead: inputMinutesread, rating: Int(inputRating), notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Book Title") {
                    HubTextField(placeholder: "Book Title", text: $inputBooktitle)
                }

                EntryFormSection(title: "Author") {
                    HubTextField(placeholder: "Author", text: $inputAuthor)
                }

                EntryFormSection(title: "Genre") {
                    Picker("Genre", selection: $selectedGenre) {
                        ForEach(BookGenre.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Status") {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(ReadingStatus.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Total Pages") {
                    Stepper("\(inputTotalpages) total pages", value: $inputTotalpages, in: 0...9999)
                }

                EntryFormSection(title: "Current Page") {
                    Stepper("\(inputCurrentpage) current page", value: $inputCurrentpage, in: 0...9999)
                }

                EntryFormSection(title: "Minutes Read") {
                    Stepper("\(inputMinutesread) minutes read", value: $inputMinutesread, in: 0...9999)
                }

                EntryFormSection(title: "Rating (1-5)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputRating))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputRating, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Notes & Highlights") {
                    HubTextField(placeholder: "Notes & Highlights", text: $inputNotes)
                }
        }
    }
}
