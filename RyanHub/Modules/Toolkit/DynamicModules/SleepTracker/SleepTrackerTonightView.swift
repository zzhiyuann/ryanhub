import SwiftUI

struct SleepTrackerTonightView: View {

    let viewModel: SleepTrackerViewModel

    @Environment(\.colorScheme) private var colorScheme

    @State private var bedTime: Date = {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 23
        c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()

    @State private var wakeTime: Date = {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 7
        c.minute = 0
        if let d = Calendar.current.date(from: c) {
            return Calendar.current.date(byAdding: .day, value: 1, to: d) ?? d
        }
        return Date()
    }()

    @State private var qualityRating: Int = 3
    @State private var wakeMood: WakeMood = .neutral
    @State private var dreamRecall: Bool = false
    @State private var notes: String = ""
    @State private var isEditing: Bool = false
    @State private var showBedTimePicker: Bool = false
    @State private var showWakeTimePicker: Bool = false
    @State private var scoreAnimationProgress: Double = 0

    private var hasEntryToday: Bool {
        viewModel.todayEntry != nil && !isEditing
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                if let entry = viewModel.todayEntry, !isEditing {
                    summaryView(entry: entry)
                } else {
                    entryFormView
                }
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.vertical, HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .onAppear {
            if let entry = viewModel.todayEntry {
                populateFromEntry(entry)
            }
        }
    }

    // MARK: - Summary View

    @ViewBuilder
    private func summaryView(entry: SleepTrackerEntry) -> some View {
        HubCard {
            VStack(spacing: HubLayout.sectionSpacing) {
                // Sleep Score Ring
                sleepScoreRing(entry: entry)

                // Duration
                Text(entry.sleepDurationFormatted)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                // Bedtime → Wake time
                HStack(spacing: HubLayout.itemSpacing) {
                    Label(entry.formattedBedTime, systemImage: "moon.fill")
                        .font(.hubBody)
                        .foregroundStyle(Color.hubPrimary)

                    Image(systemName: "arrow.right")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    Label(entry.formattedWakeTime, systemImage: "sun.max.fill")
                        .font(.hubBody)
                        .foregroundStyle(Color.hubAccentYellow)
                }

                // Quality + Mood Row
                HStack(spacing: HubLayout.sectionSpacing) {
                    // Quality stars
                    VStack(spacing: 4) {
                        Text(entry.qualityStars)
                            .font(.system(size: 18))
                        Text("Quality")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Divider()
                        .frame(height: 32)

                    // Mood
                    VStack(spacing: 4) {
                        Image(systemName: entry.wakeMood.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(moodColor(for: entry.wakeMood))
                        Text(entry.wakeMood.displayName)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    if entry.dreamRecall {
                        Divider()
                            .frame(height: 32)

                        VStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.hubPrimary)
                            Text("Dreams")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }
                }

                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }

                // Edit button
                Button {
                    populateFromEntry(entry)
                    isEditing = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.hubCaption)
                        Text("Edit")
                            .font(.hubCaption)
                    }
                    .foregroundStyle(Color.hubPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.hubPrimary.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                scoreAnimationProgress = 1.0
            }
        }
    }

    // MARK: - Sleep Score Ring

    @ViewBuilder
    private func sleepScoreRing(entry: SleepTrackerEntry) -> some View {
        let score = viewModel.sleepScore(for: entry)
        let fraction = Double(score) / 100.0
        let animatedFraction = fraction * scoreAnimationProgress

        ZStack {
            // Track
            Circle()
                .stroke(
                    AdaptiveColors.textSecondary(for: colorScheme).opacity(0.15),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 140, height: 140)

            // Gradient progress
            Circle()
                .trim(from: 0, to: animatedFraction)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: scoreGradientColors(for: score)),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-90))

            // Center text
            VStack(spacing: 2) {
                Text("\(Int(Double(score) * scoreAnimationProgress))")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(for: score))
                    .contentTransition(.numericText())

                if let grade = viewModel.todaySleepScoreGrade {
                    Text(grade.label)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }
        }
    }

    // MARK: - Entry Form

    @ViewBuilder
    private var entryFormView: some View {
        VStack(spacing: HubLayout.sectionSpacing) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.hubPrimary)

                Text("Log Last Night's Sleep")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)

            // Time pickers
            HubCard {
                VStack(spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: "Sleep Window")

                    HStack(spacing: HubLayout.itemSpacing) {
                        timePill(
                            label: "Bedtime",
                            icon: "moon.fill",
                            time: bedTime,
                            color: Color.hubPrimary,
                            isExpanded: showBedTimePicker
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showBedTimePicker.toggle()
                                if showBedTimePicker { showWakeTimePicker = false }
                            }
                        }

                        timePill(
                            label: "Wake Up",
                            icon: "sun.max.fill",
                            time: wakeTime,
                            color: Color.hubAccentYellow,
                            isExpanded: showWakeTimePicker
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showWakeTimePicker.toggle()
                                if showWakeTimePicker { showBedTimePicker = false }
                            }
                        }
                    }

                    if showBedTimePicker {
                        DatePicker("Bedtime", selection: $bedTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    if showWakeTimePicker {
                        DatePicker("Wake Time", selection: $wakeTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    // Duration preview
                    let duration = computedDuration
                    let hrs = Int(duration)
                    let mins = Int((duration - Double(hrs)) * 60)
                    Text("\(hrs)h \(mins)m")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }

            // Quality Rating
            HubCard {
                VStack(spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: "Sleep Quality")

                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                qualityRating = star
                            } label: {
                                Image(systemName: star <= qualityRating ? "star.fill" : "star")
                                    .font(.system(size: 32))
                                    .foregroundStyle(star <= qualityRating ? Color.hubAccentYellow : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3))
                            }
                            .buttonStyle(.plain)
                            .scaleEffect(star == qualityRating ? 1.15 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: qualityRating)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Wake Mood
            HubCard {
                VStack(spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: "Wake Mood")

                    HStack(spacing: 0) {
                        ForEach(WakeMood.allCases) { mood in
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                wakeMood = mood
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(wakeMood == mood ? moodColor(for: mood).opacity(0.15) : Color.clear)
                                            .frame(width: 48, height: 48)

                                        if wakeMood == mood {
                                            Circle()
                                                .stroke(moodColor(for: mood), lineWidth: 2)
                                                .frame(width: 48, height: 48)
                                        }

                                        Image(systemName: mood.icon)
                                            .font(.system(size: 22))
                                            .foregroundStyle(
                                                wakeMood == mood
                                                    ? moodColor(for: mood)
                                                    : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5)
                                            )
                                    }

                                    Text(mood.displayName)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(
                                            wakeMood == mood
                                                ? moodColor(for: mood)
                                                : AdaptiveColors.textSecondary(for: colorScheme)
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: wakeMood)
                        }
                    }
                }
            }

            // Dream Recall + Notes
            HubCard {
                VStack(spacing: HubLayout.itemSpacing) {
                    // Dream toggle
                    Toggle(isOn: $dreamRecall) {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.hubPrimary)
                            Text("Dream Recall")
                                .font(.hubBody)
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        }
                    }
                    .tint(Color.hubPrimary)

                    Divider()

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (optional)")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        TextField("How was your sleep?", text: $notes, axis: .vertical)
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            .lineLimit(3...5)
                            .textFieldStyle(.plain)
                    }
                }
            }

            // Save button
            HubButton(isEditing ? "Update Sleep Log" : "Log Sleep") {
                saveEntry()
            }
            .padding(.top, 8)

            if isEditing {
                Button {
                    isEditing = false
                } label: {
                    Text("Cancel")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }
        }
    }

    // MARK: - Time Pill

    @ViewBuilder
    private func timePill(
        label: String,
        icon: String,
        time: Date,
        color: Color,
        isExpanded: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(color)
                    Text(label)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                Text(formattedTime(time))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                    .fill(isExpanded ? color.opacity(0.08) : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                    .stroke(isExpanded ? color.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var computedDuration: Double {
        let interval = wakeTime.timeIntervalSince(bedTime)
        if interval > 0 {
            return interval / 3600.0
        }
        return (interval + 86400.0) / 3600.0
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func moodColor(for mood: WakeMood) -> Color {
        switch mood {
        case .energized: return Color.hubAccentYellow
        case .refreshed: return Color.hubAccentGreen
        case .neutral: return AdaptiveColors.textSecondary(for: colorScheme)
        case .groggy: return Color.hubPrimary
        case .exhausted: return Color.hubAccentRed
        }
    }

    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 80...100: return Color.hubAccentGreen
        case 60..<80: return Color.hubPrimaryLight
        case 40..<60: return Color.hubAccentYellow
        default: return Color.hubAccentRed
        }
    }

    private func scoreGradientColors(for score: Int) -> [Color] {
        [Color.hubAccentRed, Color.hubAccentYellow, Color.hubAccentGreen]
    }

    private func populateFromEntry(_ entry: SleepTrackerEntry) {
        bedTime = entry.bedTime
        wakeTime = entry.wakeTime
        qualityRating = entry.qualityRating
        wakeMood = entry.wakeMood
        dreamRecall = entry.dreamRecall
        notes = entry.notes
    }

    private func saveEntry() {
        let entry: SleepTrackerEntry
        if let existing = viewModel.todayEntry {
            entry = SleepTrackerEntry(
                id: existing.id,
                date: existing.date,
                bedTime: bedTime,
                wakeTime: wakeTime,
                qualityRating: max(1, min(5, qualityRating)),
                wakeMood: wakeMood,
                dreamRecall: dreamRecall,
                notes: notes
            )
            Task {
                await viewModel.deleteEntry(existing)
                await viewModel.addEntry(entry)
            }
        } else {
            entry = SleepTrackerEntry.create(
                bedTime: bedTime,
                wakeTime: wakeTime,
                qualityRating: qualityRating,
                wakeMood: wakeMood,
                dreamRecall: dreamRecall,
                notes: notes
            )
            Task {
                await viewModel.addEntry(entry)
            }
        }

        isEditing = false
        scoreAnimationProgress = 0
        withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
            scoreAnimationProgress = 1.0
        }
    }
}