import SwiftUI

struct HabitTrackerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = HabitTrackerViewModel()
    @State private var inputHabitname: String = ""
    @State private var inputIscompleted: String = ""
    @State private var inputCurrentstreak: String = ""
    @State private var inputLongeststreak: String = ""
    @State private var inputTargetdurationminutes: String = ""
    @State private var inputCompletedat: String = ""
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
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Habit Tracker")
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
                    TextField("Habit Name", text: $inputHabitname)
                        .textFieldStyle(.roundedBorder)
                    TextField("Completed Today", text: $inputIscompleted)
                        .textFieldStyle(.roundedBorder)
                    TextField("Current Streak (days)", text: $inputCurrentstreak)
                        .textFieldStyle(.roundedBorder)
                    TextField("Longest Streak (days)", text: $inputLongeststreak)
                        .textFieldStyle(.roundedBorder)
                    TextField("Target Duration (min)", text: $inputTargetdurationminutes)
                        .textFieldStyle(.roundedBorder)
                    TextField("Completed At", text: $inputCompletedat)
                        .textFieldStyle(.roundedBorder)
                    TextField("Note", text: $inputNote)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            let entry = HabitTrackerEntry(habitName: inputHabitname, isCompleted: inputIscompleted == "true", currentStreak: Int(inputCurrentstreak) ?? 0, longestStreak: Int(inputLongeststreak) ?? 0, targetDurationMinutes: Double(inputTargetdurationminutes), completedAt: inputCompletedat.isEmpty ? nil : inputCompletedat, note: inputNote.isEmpty ? nil : inputNote)
                            await viewModel.addEntry(entry)
                            inputHabitname = ""
                            inputIscompleted = ""
                            inputCurrentstreak = ""
                            inputLongeststreak = ""
                            inputTargetdurationminutes = ""
                            inputCompletedat = ""
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
                                Text("Habit Name: \(entry.habitName)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Completed Today: \(entry.isCompleted)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Current Streak (days): \(entry.currentStreak)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Longest Streak (days): \(entry.longestStreak)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                if let val = entry.targetDurationMinutes { Text("Target Duration (min): \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                if let val = entry.completedAt { Text("Completed At: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
                                if let val = entry.note { Text("Note: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
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
