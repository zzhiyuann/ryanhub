import SwiftUI

struct DailyAffirmationsEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: DailyAffirmationsViewModel
    var onSave: (() -> Void)?
    @State private var inputAffirmation: String = ""
    @State private var selectedCategory: AffirmationCategory = .selfWorth
    @State private var inputMoodbefore: Double = 5
    @State private var inputMoodafter: Double = 5
    @State private var inputResonance: Double = 5
    @State private var selectedPracticetime: PracticeTime = .morning
    @State private var inputRepetitions: Int = 1
    @State private var inputIsfavorite: Bool = false
    @State private var inputReflection: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Daily Affirmations",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = DailyAffirmationsEntry(affirmation: inputAffirmation, category: selectedCategory, moodBefore: Int(inputMoodbefore), moodAfter: Int(inputMoodafter), resonance: Int(inputResonance), practiceTime: selectedPracticetime, repetitions: inputRepetitions, isFavorite: inputIsfavorite, reflection: inputReflection)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Affirmation") {
                    HubTextField(placeholder: "Affirmation", text: $inputAffirmation)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(AffirmationCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Mood Before (1-5)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputMoodbefore))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputMoodbefore, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Mood After (1-5)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputMoodafter))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputMoodafter, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Resonance (1-5)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputResonance))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputResonance, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Practice Time") {
                    Picker("Practice Time", selection: $selectedPracticetime) {
                        ForEach(PracticeTime.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Repetitions") {
                    Stepper("\(inputRepetitions) repetitions", value: $inputRepetitions, in: 0...9999)
                }

                EntryFormSection(title: "Favorite") {
                    Toggle("Favorite", isOn: $inputIsfavorite)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Reflection Note") {
                    HubTextField(placeholder: "Reflection Note", text: $inputReflection)
                }
        }
    }
}
