import SwiftUI

struct GratitudeJournalEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: GratitudeJournalViewModel
    var onSave: (() -> Void)?
    @State private var inputGratitudeone: String = ""
    @State private var selectedThemeone: GratitudeTheme = .people
    @State private var inputGratitudetwo: String = ""
    @State private var selectedThemetwo: GratitudeTheme = .people
    @State private var inputGratitudethree: String = ""
    @State private var selectedThemethree: GratitudeTheme = .people
    @State private var inputMoodafter: Double = 5
    @State private var inputReflection: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Gratitude Journal",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = GratitudeJournalEntry(gratitudeOne: inputGratitudeone, themeOne: selectedThemeone, gratitudeTwo: inputGratitudetwo, themeTwo: selectedThemetwo, gratitudeThree: inputGratitudethree, themeThree: selectedThemethree, moodAfter: Int(inputMoodafter), reflection: inputReflection)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "I'm grateful for…") {
                    HubTextField(placeholder: "I'm grateful for…", text: $inputGratitudeone)
                }

                EntryFormSection(title: "Theme") {
                    Picker("Theme", selection: $selectedThemeone) {
                        ForEach(GratitudeTheme.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "I'm also grateful for…") {
                    HubTextField(placeholder: "I'm also grateful for…", text: $inputGratitudetwo)
                }

                EntryFormSection(title: "Theme") {
                    Picker("Theme", selection: $selectedThemetwo) {
                        ForEach(GratitudeTheme.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "And I appreciate…") {
                    HubTextField(placeholder: "And I appreciate…", text: $inputGratitudethree)
                }

                EntryFormSection(title: "Theme") {
                    Picker("Theme", selection: $selectedThemethree) {
                        ForEach(GratitudeTheme.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "How I Feel Now") {
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

                EntryFormSection(title: "Deeper Reflection (optional)") {
                    HubTextField(placeholder: "Deeper Reflection (optional)", text: $inputReflection)
                }
        }
    }
}
