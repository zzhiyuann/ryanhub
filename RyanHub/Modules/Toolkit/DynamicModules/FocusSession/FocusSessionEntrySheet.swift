import SwiftUI

struct FocusSessionEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: FocusSessionViewModel
    var onSave: (() -> Void)?
    @State private var inputDuration: Int = 1
    @State private var inputTask: String = ""
    @State private var selectedCategory: FocusCategory = .work
    @State private var selectedSessiontype: SessionType = .deepWork
    @State private var inputQuality: Double = 5
    @State private var inputCompletedfull: Bool = false
    @State private var inputDistractions: Int = 1
    @State private var inputPlannedduration: Int = 1
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Focus Sessions",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = FocusSessionEntry(duration: inputDuration, task: inputTask, category: selectedCategory, sessionType: selectedSessiontype, quality: Int(inputQuality), completedFull: inputCompletedfull, distractions: inputDistractions, plannedDuration: inputPlannedduration, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Duration (min)") {
                    Stepper("\(inputDuration) duration (min)", value: $inputDuration, in: 0...9999)
                }

                EntryFormSection(title: "Task Name") {
                    HubTextField(placeholder: "Task Name", text: $inputTask)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(FocusCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Session Type") {
                    Picker("Session Type", selection: $selectedSessiontype) {
                        ForEach(SessionType.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
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

                EntryFormSection(title: "Completed Full Session") {
                    Toggle("Completed Full Session", isOn: $inputCompletedfull)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Distractions") {
                    Stepper("\(inputDistractions) distractions", value: $inputDistractions, in: 0...9999)
                }

                EntryFormSection(title: "Planned Duration (min)") {
                    Stepper("\(inputPlannedduration) planned duration (min)", value: $inputPlannedduration, in: 0...9999)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
