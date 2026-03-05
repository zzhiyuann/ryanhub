import SwiftUI

struct GratitudeJournalEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: GratitudeJournalViewModel
    var onSave: (() -> Void)?
    @State private var inputGratitudetext: String = ""
    @State private var selectedCategory: GratitudeCategory = .people
    @State private var inputIntensity: Double = 5
    @State private var selectedMood: MoodLevel = .amazing
    @State private var inputIshighlight: Bool = false

    var body: some View {
        QuickEntrySheet(
            title: "Add Gratitude Journal",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                Task { await viewModel.addEntry(gratitudeText: inputGratitudetext, category: selectedCategory, intensity: Int(inputIntensity), mood: selectedMood, isHighlight: inputIshighlight) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "I'm grateful for…") {
                    HubTextField(placeholder: "I'm grateful for…", text: $inputGratitudetext)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(GratitudeCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "How deeply grateful (1–5)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputIntensity))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputIntensity, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Current Mood") {
                    Picker("Current Mood", selection: $selectedMood) {
                        ForEach(MoodLevel.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Mark as highlight") {
                    Toggle("Mark as highlight", isOn: $inputIshighlight)
                        .tint(Color.hubPrimary)
                }
        }
    }
}
