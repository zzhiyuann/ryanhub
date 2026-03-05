import SwiftUI

struct ScreenTimeTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ScreenTimeTrackerViewModel
    var onSave: (() -> Void)?
    @State private var selectedCategory: ScreenTimeCategory = .socialMedia
    @State private var inputDurationminutes: Int = 1
    @State private var inputIntentional: Bool = false
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Screen Time Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                Task { await viewModel.addEntry(category: selectedCategory, durationMinutes: inputDurationminutes, intentional: inputIntentional, notes: inputNotes) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ScreenTimeCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Duration (minutes)") {
                    Stepper("\(inputDurationminutes) duration (minutes)", value: $inputDurationminutes, in: 0...9999)
                }

                EntryFormSection(title: "Intentional Use") {
                    Toggle("Intentional Use", isOn: $inputIntentional)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
