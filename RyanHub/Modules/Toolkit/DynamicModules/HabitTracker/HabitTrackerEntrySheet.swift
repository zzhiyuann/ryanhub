import SwiftUI

struct HabitTrackerEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme

    let viewModel: HabitTrackerViewModel
    var onSave: (() -> Void)?

    @State private var habitName: String = ""
    @State private var category: HabitCategory = .health
    @State private var completed: Bool = false
    @State private var durationMinutes: Int = 0
    @State private var satisfaction: Int = 3
    @State private var timeOfDay: TimeOfDay = .anytime
    @State private var notes: String = ""
    @State private var date: Date = Date()

    private var canSave: Bool {
        !habitName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        QuickEntrySheet(
            title: "Add Habit Tracker",
            icon: "plus.circle.fill",
            canSave: canSave,
            onSave: saveEntry
        ) {
            EntryFormSection(title: "Habit Details") {
                TextField("Habit name", text: $habitName)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Picker("Category", selection: $category) {
                    ForEach(HabitCategory.allCases) { cat in
                        Label(cat.displayName, systemImage: cat.icon).tag(cat)
                    }
                }
                .font(.hubBody)

                Picker("Time of Day", selection: $timeOfDay) {
                    ForEach(TimeOfDay.allCases) { time in
                        Label(time.displayName, systemImage: time.icon).tag(time)
                    }
                }
                .font(.hubBody)
            }

            EntryFormSection(title: "Completion") {
                Toggle(isOn: $completed) {
                    Label("Completed", systemImage: completed ? "checkmark.circle.fill" : "circle")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
                .tint(Color.hubAccentGreen)

                Stepper(value: $durationMinutes, in: 0...480, step: 5) {
                    HStack {
                        Text("Duration")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Spacer()
                        Text(durationMinutes == 0 ? "None" : "\(durationMinutes) min")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
            }

            EntryFormSection(title: "Satisfaction") {
                HStack {
                    Text("Rating")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= satisfaction ? "star.fill" : "star")
                                .font(.system(size: 16))
                                .foregroundStyle(i <= satisfaction ? Color.hubAccentYellow : AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }
                    Text(satisfactionLabel)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .frame(minWidth: 60, alignment: .trailing)
                }

                Stepper("", value: $satisfaction, in: 1...5)
                    .labelsHidden()
            }

            EntryFormSection(title: "Date & Time") {
                DatePicker(
                    "Date",
                    selection: $date,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }

            EntryFormSection(title: "Notes") {
                TextField("Add notes (optional)...", text: $notes, axis: .vertical)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(3...6)
            }
        }
    }

    private var satisfactionLabel: String {
        switch satisfaction {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Excellent"
        default: return "—"
        }
    }

    private func saveEntry() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        let entry = HabitTrackerEntry(
            date: formatter.string(from: date),
            habitName: habitName.trimmingCharacters(in: .whitespaces),
            category: category,
            completed: completed,
            durationMinutes: durationMinutes,
            satisfaction: satisfaction,
            timeOfDay: timeOfDay,
            notes: notes.trimmingCharacters(in: .whitespaces)
        )

        Task { await viewModel.addEntry(entry) }
        onSave?()
    }
}