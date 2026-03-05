import SwiftUI

struct FocusTimerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: FocusTimerViewModel
    var onSave: (() -> Void)?
    @State private var inputTaskname: String = ""
    @State private var selectedCategory: FocusCategory = .work
    @State private var inputDuration: Int = 1
    @State private var inputCompleted: Bool = false
    @State private var inputQuality: Double = 5
    @State private var inputDistractioncount: Int = 1
    @State private var inputBreakduration: Int = 1
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Focus Timer",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = FocusTimerEntry(taskName: inputTaskname, category: selectedCategory, duration: inputDuration, completed: inputCompleted, quality: Int(inputQuality), distractionCount: inputDistractioncount, breakDuration: inputBreakduration, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Task") {
                    HubTextField(placeholder: "Task", text: $inputTaskname)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(FocusCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Duration (min)") {
                    Stepper("\(inputDuration) duration (min)", value: $inputDuration, in: 0...9999)
                }

                EntryFormSection(title: "Completed Full Session") {
                    Toggle("Completed Full Session", isOn: $inputCompleted)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Focus Quality (1-5)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputQuality))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputQuality, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Distractions") {
                    Stepper("\(inputDistractioncount) distractions", value: $inputDistractioncount, in: 0...9999)
                }

                EntryFormSection(title: "Break After (min)") {
                    Stepper("\(inputBreakduration) break after (min)", value: $inputBreakduration, in: 0...9999)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
