import SwiftUI

struct LearningTrackerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = LearningTrackerViewModel()
    @State private var inputCoursename: String = ""
    @State private var inputCategory: String = ""
    @State private var inputTotalunits: String = ""
    @State private var inputCompletedunits: String = ""
    @State private var inputProgresspercent: String = ""
    @State private var inputHoursspent: String = ""
    @State private var inputTargethours: String = ""
    @State private var inputIscompleted: String = ""
    @State private var inputLaststudieddate: String = ""
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
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Learning Tracker")
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
                    TextField("Course / Skill Name", text: $inputCoursename)
                        .textFieldStyle(.roundedBorder)
                    TextField("Category", text: $inputCategory)
                        .textFieldStyle(.roundedBorder)
                    TextField("Total Units / Lessons", text: $inputTotalunits)
                        .textFieldStyle(.roundedBorder)
                    TextField("Completed Units", text: $inputCompletedunits)
                        .textFieldStyle(.roundedBorder)
                    TextField("Progress (%)", text: $inputProgresspercent)
                        .textFieldStyle(.roundedBorder)
                    TextField("Hours Spent", text: $inputHoursspent)
                        .textFieldStyle(.roundedBorder)
                    TextField("Target Hours", text: $inputTargethours)
                        .textFieldStyle(.roundedBorder)
                    TextField("Completed", text: $inputIscompleted)
                        .textFieldStyle(.roundedBorder)
                    TextField("Last Studied", text: $inputLaststudieddate)
                        .textFieldStyle(.roundedBorder)
                    TextField("Notes", text: $inputNote)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            let entry = LearningTrackerEntry(courseName: inputCoursename, category: inputCategory, totalUnits: Int(inputTotalunits) ?? 0, completedUnits: Int(inputCompletedunits) ?? 0, progressPercent: Double(inputProgresspercent) ?? 0, hoursSpent: Double(inputHoursspent) ?? 0, targetHours: Double(inputTargethours), isCompleted: inputIscompleted == "true", lastStudiedDate: inputLaststudieddate.isEmpty ? nil : inputLaststudieddate, note: inputNote.isEmpty ? nil : inputNote)
                            await viewModel.addEntry(entry)
                            inputCoursename = ""
                            inputCategory = ""
                            inputTotalunits = ""
                            inputCompletedunits = ""
                            inputProgresspercent = ""
                            inputHoursspent = ""
                            inputTargethours = ""
                            inputIscompleted = ""
                            inputLaststudieddate = ""
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
                                Text("Course / Skill Name: \(entry.courseName)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Category: \(entry.category)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Total Units / Lessons: \(entry.totalUnits)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Completed Units: \(entry.completedUnits)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Progress (%): \(entry.progressPercent)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Hours Spent: \(entry.hoursSpent)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                if let val = entry.targetHours { Text("Target Hours: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                Text("Completed: \(entry.isCompleted)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                if let val = entry.lastStudiedDate { Text("Last Studied: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
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
