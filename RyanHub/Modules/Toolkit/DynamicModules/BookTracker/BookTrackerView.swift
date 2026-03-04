import SwiftUI

struct BookTrackerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = BookTrackerViewModel()
    @State private var inputTitle: String = ""
    @State private var inputAuthor: String = ""
    @State private var inputTotalpages: String = ""
    @State private var inputCurrentpage: String = ""
    @State private var inputProgresspercent: String = ""
    @State private var inputStartdate: String = ""
    @State private var inputIsfinished: String = ""
    @State private var inputNote: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.hubPrimary.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Book Tracker")
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Text("\(viewModel.entries.count) entries")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    Spacer()
                }

                // Add entry form
                VStack(spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: "Add Entry")
                    TextField("Book Title", text: $inputTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("Author", text: $inputAuthor)
                        .textFieldStyle(.roundedBorder)
                    TextField("Total Pages", text: $inputTotalpages)
                        .textFieldStyle(.roundedBorder)
                    TextField("Current Page", text: $inputCurrentpage)
                        .textFieldStyle(.roundedBorder)
                    TextField("Progress (%)", text: $inputProgresspercent)
                        .textFieldStyle(.roundedBorder)
                    TextField("Start Date", text: $inputStartdate)
                        .textFieldStyle(.roundedBorder)
                    TextField("Finished", text: $inputIsfinished)
                        .textFieldStyle(.roundedBorder)
                    TextField("Notes", text: $inputNote)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            let entry = BookTrackerEntry(title: inputTitle, author: inputAuthor, totalPages: Int(inputTotalpages) ?? 0, currentPage: Int(inputCurrentpage) ?? 0, progressPercent: Double(inputProgresspercent) ?? 0, startDate: inputStartdate, isFinished: inputIsfinished == "true", note: inputNote.isEmpty ? nil : inputNote)
                            await viewModel.addEntry(entry)
                            inputTitle = ""
                            inputAuthor = ""
                            inputTotalpages = ""
                            inputCurrentpage = ""
                            inputProgresspercent = ""
                            inputStartdate = ""
                            inputIsfinished = ""
                            inputNote = ""
                        }
                    } label: {
                        Text("Add")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: HubLayout.buttonHeight)
                            .background(
                                RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                                    .fill(Color.hubPrimary)
                            )
                    }
                }
                .padding(HubLayout.standardPadding)
                .background(
                    RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                        .fill(AdaptiveColors.surface(for: colorScheme))
                )

                // Entries list
                if !viewModel.entries.isEmpty {
                    VStack(spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Recent Entries")
                        ForEach(viewModel.entries.reversed()) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.date)
                                        .font(.hubBody)
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                Text("Book Title: \(entry.title)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Author: \(entry.author)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Total Pages: \(entry.totalPages)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Current Page: \(entry.currentPage)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Progress (%): \(entry.progressPercent)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Start Date: \(entry.startDate)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Finished: \(entry.isFinished)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                if let val = entry.note { Text("Notes: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                }
                                Spacer()
                                Button {
                                    Task { await viewModel.deleteEntry(entry) }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.hubAccentRed)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AdaptiveColors.surface(for: colorScheme))
                            )
                        }
                    }
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .task { await viewModel.loadData() }
    }
}
