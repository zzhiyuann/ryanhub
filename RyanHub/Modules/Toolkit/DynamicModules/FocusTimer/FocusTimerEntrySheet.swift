import SwiftUI

struct FocusTimerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: FocusTimerViewModel
    var onSave: (() -> Void)?
    @State private var inputDurationminutes: Int = 1
    @State private var inputTask: String = ""
    @State private var selectedCategory: FocusCategory = .coding
    @State private var selectedSessiontype: SessionType = .pomodoro
    @State private var inputFocusquality: Double = 5
    @State private var inputDistractioncount: Int = 1
    @State private var inputCompleted: Bool = false
    @State private var inputStarttime: Date = Date()
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Focus Timer",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = FocusTimerEntry(durationMinutes: inputDurationminutes, task: inputTask, category: selectedCategory, sessionType: selectedSessiontype, focusQuality: Int(inputFocusquality), distractionCount: inputDistractioncount, completed: inputCompleted, startTime: inputStarttime, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Duration (min)") {
                    Stepper("\(inputDurationminutes) duration (min)", value: $inputDurationminutes, in: 0...9999)
                }

                EntryFormSection(title: "Task") {
                    HubTextField(placeholder: "Task", text: $inputTask)
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

                EntryFormSection(title: "Focus Quality (1–5)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputFocusquality))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputFocusquality, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Distractions") {
                    Stepper("\(inputDistractioncount) distractions", value: $inputDistractioncount, in: 0...9999)
                }

                EntryFormSection(title: "Completed Full Session") {
                    Toggle("Completed Full Session", isOn: $inputCompleted)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Start Time") {
                    DatePicker("Start Time", selection: $inputStarttime, displayedComponents: .hourAndMinute)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
