import SwiftUI

struct DailyAffirmationsEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: DailyAffirmationsViewModel
    var onSave: (() -> Void)?
    @State private var inputAffirmation: String = ""
    @State private var selectedCategory: AffirmationCategory = .selfLove
    @State private var selectedPracticetime: PracticeTime = .morning
    @State private var inputMoodafter: Double = 5
    @State private var inputSpokenaloud: Bool = false
    @State private var inputIsfavorite: Bool = false
    @State private var inputReflection: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Daily Affirmations",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = DailyAffirmationsEntry(affirmation: inputAffirmation, category: selectedCategory, practiceTime: selectedPracticetime, moodAfter: Int(inputMoodafter), spokenAloud: inputSpokenaloud, isFavorite: inputIsfavorite, reflection: inputReflection)
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

                EntryFormSection(title: "Time of Day") {
                    Picker("Time of Day", selection: $selectedPracticetime) {
                        ForEach(PracticeTime.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Mood After (1–5)") {
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

                EntryFormSection(title: "Spoken Aloud") {
                    Toggle("Spoken Aloud", isOn: $inputSpokenaloud)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Favorite") {
                    Toggle("Favorite", isOn: $inputIsfavorite)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Reflection (optional)") {
                    HubTextField(placeholder: "Reflection (optional)", text: $inputReflection)
                }
        }
    }
}
