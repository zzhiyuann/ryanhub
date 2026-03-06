import SwiftUI

struct HabitTrackerHabitEntrySheet: View {
    let viewModel: HabitTrackerViewModel
    var onSave: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var habitIcon: String = "checkmark.circle.fill"
    @State private var category: HabitCategory = .other
    @State private var timeOfDay: TimeOfDay = .anytime
    @State private var targetDaysPerWeek: Int = 7

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        QuickEntrySheet(
            title: "Add Habit Tracker",
            icon: "plus.circle.fill",
            canSave: canSave,
            onSave: {
                let entry = HabitTrackerEntry(
                    name: name.trimmingCharacters(in: .whitespaces),
                    habitIcon: habitIcon,
                    category: category,
                    timeOfDay: timeOfDay,
                    targetDaysPerWeek: targetDaysPerWeek
                )
                Task { await viewModel.addEntry(entry) }
                onSave?()
                dismiss()
            }
        ) {
            // MARK: - Name

            EntryFormSection(title: "Name") {
                HubTextField(placeholder: "e.g. Meditate 10 min", text: $name)
            }

            // MARK: - Icon

            EntryFormSection(title: "Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: HubLayout.itemSpacing), count: 6), spacing: HubLayout.itemSpacing) {
                    ForEach(HabitTrackerEntry.curatedIcons, id: \.self) { icon in
                        Button {
                            habitIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 22))
                                .frame(width: 44, height: 44)
                                .foregroundStyle(habitIcon == icon ? Color.white : AdaptiveColors.textSecondary(for: colorScheme))
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(habitIcon == icon ? Color.hubPrimary : AdaptiveColors.surfaceSecondary(for: colorScheme))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // MARK: - Category

            EntryFormSection(title: "Category") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HubLayout.itemSpacing) {
                        ForEach(HabitCategory.allCases) { cat in
                            Button {
                                category = cat
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 14))
                                    Text(cat.displayName)
                                        .font(.hubCaption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(category == cat ? Color.white : AdaptiveColors.textSecondary(for: colorScheme))
                                .background(
                                    Capsule()
                                        .fill(category == cat ? Color.hubPrimary : AdaptiveColors.surfaceSecondary(for: colorScheme))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // MARK: - Time of Day

            EntryFormSection(title: "Time of Day") {
                Picker("Time of Day", selection: $timeOfDay) {
                    ForEach(TimeOfDay.allCases) { tod in
                        Text(tod.displayName).tag(tod)
                    }
                }
                .pickerStyle(.segmented)
            }

            // MARK: - Target Days

            EntryFormSection(title: "Target Frequency") {
                Stepper(value: $targetDaysPerWeek, in: 1...7) {
                    HStack {
                        Text(targetDaysPerWeek == 7 ? "Daily" : "\(targetDaysPerWeek) days/week")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    }
                }
            }
        }
    }
}