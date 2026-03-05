import SwiftUI

struct GratitudeJournalEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: GratitudeJournalViewModel
    var onSave: (() -> Void)?
    @State private var inputGratitudetext: String = ""
    @State private var selectedCategory: GratitudeCategory = .people
    @State private var inputDepth: Double = 5
    @State private var selectedMood: EntryMood = .joyful

    var body: some View {
        QuickEntrySheet(
            title: "Add Gratitude Journal",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = GratitudeJournalEntry(gratitudeText: inputGratitudetext, category: selectedCategory, depth: Int(inputDepth), mood: selectedMood)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "I'm grateful for…") {
                    HubTextField(placeholder: "I'm grateful for…", text: $inputGratitudetext)
                }

                EntryFormSection(title: "Life Area") {
                    Picker("Life Area", selection: $selectedCategory) {
                        ForEach(GratitudeCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "How deeply felt") {
                    VStack {
                        HStack {
                            Text("\(Int(inputDepth))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputDepth, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Current Mood") {
                    Picker("Current Mood", selection: $selectedMood) {
                        ForEach(EntryMood.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }
        }
    }
}
