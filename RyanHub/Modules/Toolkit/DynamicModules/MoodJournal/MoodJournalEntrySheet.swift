import SwiftUI

struct MoodJournalEntrySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: MoodJournalViewModel
    var onSave: (() -> Void)?

    @State private var entry = MoodJournalEntry()
    @State private var selectedDate = Date()

    private var moodBinding: Binding<Double> {
        Binding(get: { Double(entry.moodRating) }, set: { entry.moodRating = Int($0.rounded()) })
    }

    private var energyBinding: Binding<Double> {
        Binding(get: { Double(entry.energyLevel) }, set: { entry.energyLevel = Int($0.rounded()) })
    }

    private var anxietyBinding: Binding<Double> {
        Binding(get: { Double(entry.anxietyLevel) }, set: { entry.anxietyLevel = Int($0.rounded()) })
    }

    var body: some View {
        QuickEntrySheet(
            title: "Add Mood Journal",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm"
                entry.date = f.string(from: selectedDate)
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {
            EntryFormSection(title: "Date & Time") {
                DatePicker(
                    "Date & Time",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }

            EntryFormSection(title: "Mood") {
                VStack(spacing: HubLayout.itemSpacing) {
                    HStack {
                        Text("Mood")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Spacer()
                        Text("\(entry.moodRating)/10  \(entry.moodEmoji)  \(entry.moodLabel)")
                            .font(.hubCaption)
                            .foregroundStyle(Color.hubPrimary)
                    }
                    Slider(value: moodBinding, in: 1...10, step: 1)
                        .tint(Color.hubPrimary)
                }
            }

            EntryFormSection(title: "Energy") {
                VStack(spacing: HubLayout.itemSpacing) {
                    HStack {
                        Text("Energy Level")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Spacer()
                        Text("\(entry.energyLevel)/10  \(entry.energyLabel)")
                            .font(.hubCaption)
                            .foregroundStyle(Color.hubAccentGreen)
                    }
                    Slider(value: energyBinding, in: 1...10, step: 1)
                        .tint(Color.hubAccentGreen)
                }
            }

            EntryFormSection(title: "Anxiety") {
                VStack(spacing: HubLayout.itemSpacing) {
                    HStack {
                        Text("Anxiety Level")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Spacer()
                        Text("\(entry.anxietyLevel)/10  \(entry.anxietyLabel)")
                            .font(.hubCaption)
                            .foregroundStyle(Color.hubAccentRed)
                    }
                    Slider(value: anxietyBinding, in: 1...10, step: 1)
                        .tint(Color.hubAccentRed)
                }
            }

            EntryFormSection(title: "Activity") {
                Picker("Activity", selection: $entry.activity) {
                    ForEach(MoodActivity.allCases) { activity in
                        Label(activity.displayName, systemImage: activity.icon)
                            .tag(activity)
                    }
                }
                .pickerStyle(.menu)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            EntryFormSection(title: "Social Context") {
                Picker("Social Context", selection: $entry.socialContext) {
                    ForEach(SocialContext.allCases) { context in
                        Label(context.displayName, systemImage: context.icon)
                            .tag(context)
                    }
                }
                .pickerStyle(.menu)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            EntryFormSection(title: "Notes") {
                TextField(
                    "How are you feeling? (optional)",
                    text: $entry.notes,
                    axis: .vertical
                )
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .lineLimit(3...6)
            }
        }
    }
}