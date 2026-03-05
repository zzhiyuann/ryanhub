import SwiftUI

struct SleepTrackerEntrySheet: View {
    let viewModel: SleepTrackerViewModel
    var onSave: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    @State private var bedtime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var wakeTime: Date = Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var qualityRating: Int = 3
    @State private var wakeUpMood: WakeUpMood = .neutral
    @State private var sleepDisruptor: SleepDisruptor = .none
    @State private var dreamRecall: Bool = false
    @State private var notes: String = ""

    var body: some View {
        QuickEntrySheet(
            title: "Add Sleep Tracker",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {
                var entry = SleepTrackerEntry()
                entry.bedtime = bedtime
                entry.wakeTime = wakeTime
                entry.qualityRating = qualityRating
                entry.wakeUpMood = wakeUpMood
                entry.sleepDisruptor = sleepDisruptor
                entry.dreamRecall = dreamRecall
                entry.notes = notes
                Task { await viewModel.addEntry(entry) }
                onSave?()
            }
        ) {
            EntryFormSection(title: "Sleep Times") {
                DatePicker("Bedtime", selection: $bedtime, displayedComponents: .hourAndMinute)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .font(.hubBody)

                DatePicker("Wake Time", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .font(.hubBody)

                HStack {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundStyle(Color.hubPrimary)
                    Text("Duration")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    Spacer()
                    Text(computedDurationLabel)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
                .padding(.vertical, 2)
            }

            EntryFormSection(title: "Sleep Quality") {
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    HStack {
                        Text("Rating")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Spacer()
                        Text(qualityStarsLabel)
                            .font(.hubBody)
                        Text("(\(qualityRating)/\(SleepTrackerConstants.maxQualityRating))")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    Slider(
                        value: Binding(
                            get: { Double(qualityRating) },
                            set: { qualityRating = Int($0.rounded()) }
                        ),
                        in: Double(SleepTrackerConstants.minQualityRating)...Double(SleepTrackerConstants.maxQualityRating),
                        step: 1
                    )
                    .tint(Color.hubPrimary)
                }
            }

            EntryFormSection(title: "Wake Up Mood") {
                Picker("Mood", selection: $wakeUpMood) {
                    ForEach(WakeUpMood.allCases) { mood in
                        Label(mood.displayName, systemImage: mood.icon)
                            .tag(mood)
                    }
                }
                .pickerStyle(.menu)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }

            EntryFormSection(title: "Sleep Disruptor") {
                Picker("Disruptor", selection: $sleepDisruptor) {
                    ForEach(SleepDisruptor.allCases) { disruptor in
                        Label(disruptor.displayName, systemImage: disruptor.icon)
                            .tag(disruptor)
                    }
                }
                .pickerStyle(.menu)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }

            EntryFormSection(title: "Additional Details") {
                Toggle(isOn: $dreamRecall) {
                    HStack(spacing: HubLayout.itemSpacing) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.hubAccentYellow)
                        Text("Dream Recall")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    }
                }
                .tint(Color.hubPrimary)

                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }
        }
    }

    // MARK: - Helpers

    private var computedDurationLabel: String {
        let interval = wakeTime.timeIntervalSince(bedtime)
        let adjusted = interval < 0 ? interval + 86_400 : interval
        let hours = Int(adjusted / 3_600)
        let minutes = Int((adjusted.truncatingRemainder(dividingBy: 3_600)) / 60)
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    private var qualityStarsLabel: String {
        String(repeating: "★", count: qualityRating) +
        String(repeating: "☆", count: SleepTrackerConstants.maxQualityRating - qualityRating)
    }
}