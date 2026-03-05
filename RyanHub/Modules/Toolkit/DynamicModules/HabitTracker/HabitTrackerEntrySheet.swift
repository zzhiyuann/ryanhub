import SwiftUI

struct HabitTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: HabitTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputHabitname: String = ""
    @State private var selectedCategory: HabitCategory = .mindfulness
    @State private var inputCompleted: Bool = false
    @State private var inputDurationminutes: Int = 1
    @State private var inputDifficulty: Double = 5
    @State private var selectedTimeslot: HabitTimeSlot = .morning
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Habit Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = HabitTrackerEntry(habitName: inputHabitname, category: selectedCategory, completed: inputCompleted, durationMinutes: inputDurationminutes, difficulty: Int(inputDifficulty), timeSlot: selectedTimeslot, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Habit") {
                    HubTextField(placeholder: "Habit", text: $inputHabitname)
                }

                EntryFormSection(title: "Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(HabitCategory.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Completed") {
                    Toggle("Completed", isOn: $inputCompleted)
                        .tint(Color.hubPrimary)
                }

                EntryFormSection(title: "Duration (min)") {
                    Stepper("\(inputDurationminutes) duration (min)", value: $inputDurationminutes, in: 0...9999)
                }

                EntryFormSection(title: "Difficulty (1-5)") {
                    VStack {
                        HStack {
                            Text("\(Int(inputDifficulty))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }
                        Slider(value: $inputDifficulty, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }
                }

                EntryFormSection(title: "Time of Day") {
                    Picker("Time of Day", selection: $selectedTimeslot) {
                        ForEach(HabitTimeSlot.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Notes") {
                    HubTextField(placeholder: "Notes", text: $inputNotes)
                }
        }
    }
}
