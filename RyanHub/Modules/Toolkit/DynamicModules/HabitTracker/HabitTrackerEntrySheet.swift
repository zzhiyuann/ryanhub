import SwiftUI

struct HabitTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: HabitTrackerViewModel
    var onSave: (() -> Void)?
    @State private var inputHabitname: String = ""
    @State private var selectedCategory: HabitCategory = .mindfulness
    @State private var inputCompleted: Bool = false
    @State private var inputDuration: Int = 1
    @State private var inputQuality: Double = 5
    @State private var selectedTimeofday: TimeOfDay = .morning
    @State private var inputNotes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Habit Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let entry = HabitTrackerEntry(habitName: inputHabitname, category: selectedCategory, completed: inputCompleted, duration: inputDuration, quality: Int(inputQuality), timeOfDay: selectedTimeofday, notes: inputNotes)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {

                EntryFormSection(title: "Habit Name") {
                    HubTextField(placeholder: "Habit Name", text: $inputHabitname)
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
                    Stepper("\(inputDuration) duration (min)", value: $inputDuration, in: 0...9999)
                }

                EntryFormSection(title: "Session Quality") {
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

                EntryFormSection(title: "Time of Day") {
                    Picker("Time of Day", selection: $selectedTimeofday) {
                        ForEach(TimeOfDay.allCases) { item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                EntryFormSection(title: "Reflection Notes") {
                    HubTextField(placeholder: "Reflection Notes", text: $inputNotes)
                }
        }
    }
}
