import SwiftUI

struct MoodJournalEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: MoodJournalViewModel
    var onSave: (() -> Void)?
    @State private var inputRating: Double = 5
    @State private var inputEnergy: Double = 5
    @State private var selectedEmotion: MoodEmotion = .happy
    @State private var inputActivities: Set<MoodActivity> = []
    @State private var inputSleepquality: Double = 5
    @State private var selectedSociallevel: SocialLevel = .alone
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Mood Journal",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = MoodJournalEntry(rating: Int(inputRating), energy: Int(inputEnergy), emotion: selectedEmotion, activities: Array(inputActivities), sleepQuality: Int(inputSleepquality), socialLevel: selectedSociallevel, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Mood Rating") {
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

                EntryFormSection(title: "Energy Level") {
                    VStack {
                        HStack {
                            Text("\(Int(inputEnergy))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputEnergy, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Primary Emotion") {
                    Picker("Primary Emotion", selection: $selectedEmotion) {
                        ForEach(MoodEmotion.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Activities") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                        ForEach(MoodActivity.allCases) { activity in
                            Button {
                                if inputActivities.contains(activity) {
                                    inputActivities.remove(activity)
                                } else {
                                    inputActivities.insert(activity)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: activity.icon)
                                        .font(.caption)
                                    Text(activity.displayName)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(inputActivities.contains(activity) ? Color.hubPrimary.opacity(0.2) : AdaptiveColors.surfaceSecondary(for: colorScheme))
                                .foregroundStyle(inputActivities.contains(activity) ? Color.hubPrimary : AdaptiveColors.textSecondary(for: colorScheme))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }

                EntryFormSection(title: "Sleep Quality") {
                    VStack {
                        HStack {
                            Text("\(Int(inputSleepquality))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputSleepquality, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Social Interaction") {
                    Picker("Social Interaction", selection: $selectedSociallevel) {
                        ForEach(SocialLevel.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Journal Notes") {
                    HubTextField(placeholder: "Journal Notes", text: $inputNotes)
                }
        }
    }
}
