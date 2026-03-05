import SwiftUI

struct MoodJournalEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: MoodJournalViewModel
    var onSave: (() -> Void)?
    @State private var inputMoodrating: Double = 5
    @State private var selectedPrimaryemotion: PrimaryEmotion = .happy
    @State private var inputEnergylevel: Double = 5
    @State private var selectedContext: MoodContext = .work
    @State private var inputSleepquality: Double = 5
    @State private var inputGratitudenote: String = ""
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Mood Journal",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = MoodJournalEntry(moodRating: Int(inputMoodrating), primaryEmotion: selectedPrimaryemotion, energyLevel: Int(inputEnergylevel), context: selectedContext, sleepQuality: Int(inputSleepquality), gratitudeNote: inputGratitudenote, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Mood Rating (1-10)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputMoodrating))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputMoodrating, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Primary Emotion") {
                    Picker("Primary Emotion", selection: $selectedPrimaryemotion) {
                        ForEach(PrimaryEmotion.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Energy Level (1-5)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputEnergylevel))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputEnergylevel, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "What Were You Doing") {
                    Picker("What Were You Doing", selection: $selectedContext) {
                        ForEach(MoodContext.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Last Night's Sleep (1-5)") {
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

                EntryFormSection(title: "Something You're Grateful For") {
                    HubTextField(placeholder: "Something You're Grateful For", text: $inputGratitudenote)
                }

                EntryFormSection(title: "Journal Notes") {
                    HubTextField(placeholder: "Journal Notes", text: $inputNotes)
                }
        }
    }
}
