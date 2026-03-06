import SwiftUI

struct HabitTrackerTodayView: View {
    let viewModel: HabitTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var locallyCompleted: Set<String> = []
    @State private var animatingIds: Set<String> = []
    @State private var expandedSections: Set<TimeOfDay> = Set(TimeOfDay.allCases)

    // MARK: - Derived Data

    private var uniqueHabits: [HabitTrackerEntry] {
        var latest: [String: HabitTrackerEntry] = [:]
        for entry in viewModel.entries where !entry.isArchived {
            if let existing = latest[entry.name] {
                if entry.date > existing.date { latest[entry.name] = entry }
            } else {
                latest[entry.name] = entry
            }
        }
        return Array(latest.values)
    }

    private var todayCompletedNames: Set<String> {
        Set(viewModel.todayEntries.map(\.name))
    }

    private var totalCount: Int { uniqueHabits.count }

    private var completedCount: Int {
        uniqueHabits.filter { isCompleted($0) }.count
    }

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    private var motivationalLabel: String {
        if totalCount == 0 { return "Add some habits to get started!" }
        if completedCount == totalCount { return "All done — incredible day!" }
        if Double(completedCount) >= Double(totalCount) * 0.75 { return "Almost there, finish strong!" }
        if Double(completedCount) >= Double(totalCount) * 0.5 { return "Over halfway — keep going!" }
        if completedCount > 0 { return "Great start, keep it up!" }
        return "Let's make today count!"
    }

    private var activeSections: [TimeOfDay] {
        TimeOfDay.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .filter { timeOfDay in
                uniqueHabits.contains { $0.timeOfDay == timeOfDay }
            }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                progressHeader
                if uniqueHabits.isEmpty {
                    emptyState
                } else {
                    habitSections
                }
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.vertical, HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                ProgressRingView(
                    progress: progress,
                    current: "\(completedCount)/\(totalCount)",
                    goal: "completed",
                    color: completedCount == totalCount && totalCount > 0
                        ? Color.hubAccentGreen
                        : Color.hubPrimary,
                    size: 140,
                    lineWidth: 14
                )
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)

                Text(motivationalLabel)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HubLayout.itemSpacing)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                Image(systemName: "checklist")
                    .font(.system(size: 40))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4))
                Text("No habits yet")
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HubLayout.sectionSpacing)
        }
    }

    // MARK: - Habit Sections

    private var habitSections: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            ForEach(activeSections) { timeOfDay in
                sectionCard(for: timeOfDay)
            }
        }
    }

    private func sortedHabits(for timeOfDay: TimeOfDay) -> [HabitTrackerEntry] {
        uniqueHabits
            .filter { $0.timeOfDay == timeOfDay }
            .sorted { a, b in
                let aDone = isCompleted(a)
                let bDone = isCompleted(b)
                if aDone != bDone { return !aDone }
                return a.name < b.name
            }
    }

    private func sectionCard(for timeOfDay: TimeOfDay) -> some View {
        let habits = sortedHabits(for: timeOfDay)
        let isExpanded = expandedSections.contains(timeOfDay)
        let sectionDone = habits.filter { isCompleted($0) }.count

        return HubCard {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if isExpanded {
                            expandedSections.remove(timeOfDay)
                        } else {
                            expandedSections.insert(timeOfDay)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: timeOfDay.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.hubPrimary)

                        Text(timeOfDay.displayName)
                            .font(.hubCaption)
                            .fontWeight(.semibold)
                            .textCase(.uppercase)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        Text("\(sectionDone)/\(habits.count)")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.6))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .padding(.horizontal, HubLayout.standardPadding)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Divider().padding(.horizontal, HubLayout.standardPadding)

                    ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                        habitRow(habit)

                        if index < habits.count - 1 {
                            Divider()
                                .padding(.leading, 60)
                                .padding(.trailing, HubLayout.standardPadding)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Habit Row

    private func habitRow(_ habit: HabitTrackerEntry) -> some View {
        let completed = isCompleted(habit)
        let isAnimating = animatingIds.contains(habit.id)
        let streak = streakForHabit(habit)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(categoryColor(for: habit.category).opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: habit.habitIcon)
                    .font(.system(size: 15))
                    .foregroundStyle(categoryColor(for: habit.category))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.hubBody)
                    .foregroundStyle(
                        completed
                            ? AdaptiveColors.textSecondary(for: colorScheme)
                            : AdaptiveColors.textPrimary(for: colorScheme)
                    )

                if streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.hubAccentYellow)

                        Text("\(streak)")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
            }

            Spacer()

            Button {
                guard !completed else { return }
                markComplete(habit)
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(
                            completed
                                ? Color.hubAccentGreen
                                : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 30, height: 30)

                    if completed {
                        Circle()
                            .fill(Color.hubAccentGreen)
                            .frame(width: 30, height: 30)

                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .scaleEffect(isAnimating ? 1.3 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(completed)
        }
        .padding(.horizontal, HubLayout.standardPadding)
        .padding(.vertical, 10)
        .background(
            completed
                ? Color.hubAccentGreen.opacity(0.06)
                : Color.clear
        )
    }

    // MARK: - Actions

    private func isCompleted(_ habit: HabitTrackerEntry) -> Bool {
        locallyCompleted.contains(habit.name) || todayCompletedNames.contains(habit.name)
    }

    private func markComplete(_ habit: HabitTrackerEntry) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            locallyCompleted.insert(habit.name)
            animatingIds.insert(habit.id)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.2)) {
                _ = animatingIds.remove(habit.id)
            }
        }

        var completionEntry = habit
        completionEntry.id = UUID().uuidString
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        completionEntry.date = f.string(from: Date())

        Task {
            await viewModel.addEntry(completionEntry)
        }
    }

    // MARK: - Helpers

    private func streakForHabit(_ habit: HabitTrackerEntry) -> Int {
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let dates = viewModel.entries
            .filter { $0.name == habit.name }
            .compactMap { df.date(from: String($0.date.prefix(10))) }
            .map { calendar.startOfDay(for: $0) }

        let uniqueDates = Array(Set(dates)).sorted(by: >)
        guard !uniqueDates.isEmpty else { return 0 }

        var streak = 0
        var expected = calendar.startOfDay(for: Date())

        if !uniqueDates.contains(expected) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: expected) else { return 0 }
            expected = yesterday
        }

        for date in uniqueDates {
            if date == expected {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: expected) else { break }
                expected = prev
            } else if date < expected {
                break
            }
        }

        return streak
    }

    private func categoryColor(for category: HabitCategory) -> Color {
        switch category {
        case .health: return Color.hubAccentGreen
        case .mindfulness: return Color.hubPrimary
        case .productivity: return Color.hubAccentYellow
        case .fitness: return Color.hubAccentRed
        case .learning: return Color.hubPrimary
        case .selfCare: return Color(red: 0.85, green: 0.45, blue: 0.68)
        case .social: return Color(red: 0.35, green: 0.68, blue: 0.92)
        case .other: return Color.hubPrimary
        }
    }
}