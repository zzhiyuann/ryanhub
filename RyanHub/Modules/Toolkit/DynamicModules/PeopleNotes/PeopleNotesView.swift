import SwiftUI

struct PeopleNotesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = PeopleNotesViewModel()
    @State private var inputPersonname: String = ""
    @State private var inputRole: String = ""
    @State private var inputCompany: String = ""
    @State private var inputMeetingcontext: String = ""
    @State private var inputLocation: String = ""
    @State private var inputDatemet: String = ""
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
                        Image(systemName: "person.text.rectangle.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("People Notes")
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
                    TextField("Name", text: $inputPersonname)
                        .textFieldStyle(.roundedBorder)
                    TextField("Role / Title", text: $inputRole)
                        .textFieldStyle(.roundedBorder)
                    TextField("Company / Organization", text: $inputCompany)
                        .textFieldStyle(.roundedBorder)
                    TextField("Meeting Context", text: $inputMeetingcontext)
                        .textFieldStyle(.roundedBorder)
                    TextField("Location", text: $inputLocation)
                        .textFieldStyle(.roundedBorder)
                    TextField("Date Met", text: $inputDatemet)
                        .textFieldStyle(.roundedBorder)
                    TextField("Notes", text: $inputNote)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            let entry = PeopleNotesEntry(personName: inputPersonname, role: inputRole.isEmpty ? nil : inputRole, company: inputCompany.isEmpty ? nil : inputCompany, meetingContext: inputMeetingcontext, location: inputLocation.isEmpty ? nil : inputLocation, dateMet: inputDatemet, note: inputNote.isEmpty ? nil : inputNote)
                            await viewModel.addEntry(entry)
                            inputPersonname = ""
                            inputRole = ""
                            inputCompany = ""
                            inputMeetingcontext = ""
                            inputLocation = ""
                            inputDatemet = ""
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
                                Text("Name: \(entry.personName)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                if let val = entry.role { Text("Role / Title: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                if let val = entry.company { Text("Company / Organization: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                Text("Meeting Context: \(entry.meetingContext)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                if let val = entry.location { Text("Location: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                Text("Date Met: \(entry.dateMet)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
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
