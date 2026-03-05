import SwiftUI

struct DailyAffirmationsEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: DailyAffirmationsViewModel
    var onSave: (() -> Void)?
    @State private var inputAffirmationtext: String = ""
    @State private var selectedCategory: AffirmationCategory = .selfWorth
    @State private var inputMoodbefore: Double = 5
    @State private var inputMoodafter: Double = 5
    @State private var inputPracticeminutes: Int = 1
    @State private var inputIsfavorite: Bool = false
    @State private var inputReflectionnote: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Daily Affirmations",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = DailyAffirmationsEntry(affirmationText: inputAffirmationtext, category: selectedCategory, moodBefore: Int(inputMoodbefore), moodAfter: Int(inputMoodafter), practiceMinutes: inputPracticeminutes, isFavorite: inputIsfavorite, reflectionNote: inputReflectionnote)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Affirmation") {
                    HubTextField(placeholder: "Affirmation", text: $inputAffirmationtext)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(AffirmationCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Mood Before Practice") {
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

                EntryFormSection(title: "Mood After Practice") {
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

                EntryFormSection(title: "Practice Duration (min)") {
                    Stepper("\(inputPracticeminutes) practice duration (min)", value: $inputPracticeminutes, in: 0...9999)
                }

                EntryFormSection(title: "Favorite") {
                    Toggle("Favorite", isOn: $inputIsfavorite)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Reflection") {
                    HubTextField(placeholder: "Reflection", text: $inputReflectionnote)
                }
        }
    }
}
