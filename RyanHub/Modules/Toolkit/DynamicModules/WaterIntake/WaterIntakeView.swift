import SwiftUI

struct WaterIntakeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = WaterIntakeViewModel()
    @State private var inputGlassesconsumed: String = ""
    @State private var inputDailygoal: String = ""
    @State private var inputGlasssizeml: String = ""
    @State private var inputTotalml: String = ""
    @State private var inputGoalreached: String = ""
    @State private var inputLastdrinktime: String = ""
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
                        Image(systemName: "drop.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Water Intake")
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
                    TextField("Glasses Consumed", text: $inputGlassesconsumed)
                        .textFieldStyle(.roundedBorder)
                    TextField("Daily Goal (glasses)", text: $inputDailygoal)
                        .textFieldStyle(.roundedBorder)
                    TextField("Glass Size (mL)", text: $inputGlasssizeml)
                        .textFieldStyle(.roundedBorder)
                    TextField("Total Intake (mL)", text: $inputTotalml)
                        .textFieldStyle(.roundedBorder)
                    TextField("Goal Reached", text: $inputGoalreached)
                        .textFieldStyle(.roundedBorder)
                    TextField("Last Drink Time", text: $inputLastdrinktime)
                        .textFieldStyle(.roundedBorder)
                    TextField("Note", text: $inputNote)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            let entry = WaterIntakeEntry(glassesConsumed: Int(inputGlassesconsumed) ?? 0, dailyGoal: Int(inputDailygoal) ?? 0, glassSizeML: Double(inputGlasssizeml) ?? 0, totalML: Double(inputTotalml) ?? 0, goalReached: inputGoalreached == "true", lastDrinkTime: inputLastdrinktime.isEmpty ? nil : inputLastdrinktime, note: inputNote.isEmpty ? nil : inputNote)
                            await viewModel.addEntry(entry)
                            inputGlassesconsumed = ""
                            inputDailygoal = ""
                            inputGlasssizeml = ""
                            inputTotalml = ""
                            inputGoalreached = ""
                            inputLastdrinktime = ""
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
                                Text("Glasses Consumed: \(entry.glassesConsumed)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Daily Goal (glasses): \(entry.dailyGoal)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Glass Size (mL): \(entry.glassSizeML)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Total Intake (mL): \(entry.totalML)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("Goal Reached: \(entry.goalReached)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                if let val = entry.lastDrinkTime { Text("Last Drink Time: \(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }
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
