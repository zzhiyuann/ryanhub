import SwiftUI

struct MedicationTrackerDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: MedicationTrackerViewModel

    // MARK: - Local Computed Properties

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var todayEntries: [MedicationTrackerEntry] {
        viewModel.entries.filter { $0.dateOnly == todayString }
    }

    private var takenToday: Int {
        todayEntries.filter { $0.status == .taken }.count
    }

    private var missedToday: Int {
        todayEntries.filter { $0.status == .missed }.count
    }

    private var scheduledToday: Int {
        todayEntries.count
    }

    private var adherenceToday: Double {
        guard scheduledToday > 0 else { return 0 }
        return Double(takenToday) / Double(scheduledToday)
    }

    private var adherencePercent: Int {
        Int((adherenceToday * 100).rounded())
    }

    private var recentEntries: [MedicationTrackerEntry] {
        viewModel.entries
            .sorted { ($0.parsedDate ?? Date.distantPast) > ($1.parsedDate ?? Date.distantPast) }
            .prefix(5)
            .map { $0 }
    }

    private var weekAdherenceRate: Double {
        let cal = Calendar.current
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let weekEntries = viewModel.entries.filter {
            guard let d = $0.parsedDate else { return false }
            return d >= sevenDaysAgo
        }
        guard !weekEntries.isEmpty else { return 0 }
        let taken = weekEntries.filter { $0.status == .taken }.count
        return Double(taken) / Double(weekEntries.count)
    }

    private var uniqueMedicationCount: Int {
        Set(viewModel.entries.map { $0.medicationName }).filter { !$0.isEmpty }.count
    }

    private var nextDose: MedicationTrackerEntry? {
        todayEntries
            .filter { $0.status != .taken && $0.status != .skipped }
            .sorted { $0.scheduledTime < $1.scheduledTime }
            .first
    }

    private var currentStreak: Int {
        var streak = 0
        let cal = Calendar.current
        var checkDate = Date()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"

        while true {
            let dateStr = f.string(from: checkDate)
            let dayEntries = viewModel.entries.filter { $0.dateOnly == dateStr }
            if dayEntries.isEmpty { break }
            let allTaken = dayEntries.allSatisfy { $0.status == .taken }
            if !allTaken { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    private var longestStreak: Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let grouped = Dictionary(grouping: viewModel.entries) { $0.dateOnly }
        let sortedDates = grouped.keys.sorted()
        var longest = 0
        var current = 0
        let cal = Calendar.current

        for (i, dateStr) in sortedDates.enumerated() {
            let dayEntries = grouped[dateStr] ?? []
            let allTaken = dayEntries.allSatisfy { $0.status == .taken }
            if allTaken {
                if i == 0 {
                    current = 1
                } else {
                    let prevStr = sortedDates[i - 1]
                    let fmtPrev = f.date(from: prevStr)
                    let fmtCurr = f.date(from: dateStr)
                    if let p = fmtPrev, let c = fmtCurr,
                       cal.dateComponents([.day], from: p, to: c).day == 1 {
                        current += 1
                    } else {
                        current = 1
                    }
                }
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }

    private var isTodayPerfect: Bool {
        !todayEntries.isEmpty && todayEntries.allSatisfy { $0.status == .taken }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                adherenceRingSection
                statGridSection
                streakSection
                nextDoseSection
                recentEntriesSection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Adherence Ring

    private var adherenceRingSection: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Adherence")
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Text(todayEntries.isEmpty ? "No doses scheduled" : "\(takenToday) of \(scheduledToday) doses taken")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    Spacer()
                    if isTodayPerfect {
                        Label("Perfect", systemImage: "star.fill")
                            .font(.hubCaption)
                            .foregroundStyle(Color.hubAccentYellow)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.hubAccentYellow.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: HubLayout.sectionSpacing) {
                    ProgressRingView(
                        progress: adherenceToday,
                        current: "\(adherencePercent)%",
                        unit: "today",
                        goal: scheduledToday > 0 ? "of \(scheduledToday) doses" : nil,
                        color: adherenceToday >= 0.8 ? Color.hubAccentGreen : adherenceToday >= 0.5 ? Color.hubAccentYellow : Color.hubAccentRed,
                        size: 130,
                        lineWidth: 12
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        doseStatusRow(icon: "checkmark.circle.fill", label: "Taken", count: takenToday, color: Color.hubAccentGreen)
                        doseStatusRow(icon: "xmark.circle.fill", label: "Missed", count: missedToday, color: Color.hubAccentRed)
                        doseStatusRow(icon: "forward.fill", label: "Skipped", count: todayEntries.filter { $0.status == .skipped }.count, color: Color.hubAccentYellow)
                        doseStatusRow(icon: "clock.arrow.circlepath", label: "Delayed", count: todayEntries.filter { $0.status == .delayed }.count, color: Color.hubPrimary)
                    }
                    Spacer()
                }
            }
            .padding(HubLayout.standardPadding)
        }
    }

    private func doseStatusRow(icon: String, label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            Spacer()
            Text("\(count)")
                .font(.hubCaption)
                .fontWeight(.semibold)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
        }
    }

    // MARK: - Stat Grid

    private var statGridSection: some View {
        StatGrid {
            StatCard(
                title: "7-Day Rate",
                value: "\(Int((weekAdherenceRate * 100).rounded()))%",
                icon: "calendar.badge.checkmark",
                color: weekAdherenceRate >= 0.8 ? Color.hubAccentGreen : Color.hubAccentYellow
            )
            StatCard(
                title: "Medications",
                value: "\(uniqueMedicationCount)",
                icon: "pills.fill",
                color: Color.hubPrimary
            )
            StatCard(
                title: "Total Logged",
                value: "\(viewModel.entries.count)",
                icon: "list.bullet.clipboard.fill",
                color: Color.hubPrimary
            )
            StatCard(
                title: "Side Effects",
                value: "\(viewModel.entries.filter { $0.hasSideEffects }.count)",
                icon: "exclamationmark.triangle.fill",
                color: Color.hubAccentYellow
            )
        }
    }

    // MARK: - Streak

    private var streakSection: some View {
        HubCard {
            VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                SectionHeader(title: "Consistency")
                StreakCounter(
                    currentStreak: currentStreak,
                    longestStreak: longestStreak,
                    unit: "days",
                    isActiveToday: isTodayPerfect
                )
            }
            .padding(HubLayout.standardPadding)
        }
    }

    // MARK: - Next Dose

    @ViewBuilder
    private var nextDoseSection: some View {
        if let next = nextDose {
            HubCard {
                HStack(spacing: HubLayout.itemSpacing) {
                    ZStack {
                        Circle()
                            .fill(Color.hubPrimary.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: next.medicationForm.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(Color.hubPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next Dose")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Text(next.medicationName.isEmpty ? "Unnamed medication" : next.medicationName)
                            .font(.hubBody)
                            .fontWeight(.semibold)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Text("\(next.dosageDescription) · \(next.timeOfDay.displayName) · \(next.scheduledTimeFormatted)")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    Image(systemName: next.timeOfDay.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(Color.hubPrimary.opacity(0.6))
                }
                .padding(HubLayout.standardPadding)
            }
        }
    }

    // MARK: - Recent Entries

    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Recent Doses")

            if recentEntries.isEmpty {
                HubCard {
                    VStack(spacing: 12) {
                        Image(systemName: "pills")
                            .font(.system(size: 36))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Text("No doses logged yet")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HubLayout.sectionSpacing)
                }
            } else {
                ForEach(recentEntries) { entry in
                    recentEntryRow(entry)
                }
            }
        }
    }

    private func recentEntryRow(_ entry: MedicationTrackerEntry) -> some View {
        HubCard {
            HStack(spacing: HubLayout.itemSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(statusColor(entry.status).opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: entry.status.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(statusColor(entry.status))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.summaryLine)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Label(entry.timeOfDay.displayName, systemImage: entry.timeOfDay.icon)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        if entry.withFood {
                            Label("With food", systemImage: "fork.knife")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }
                    Text(entry.formattedDate)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                Spacer()

                Button {
                    Task { await viewModel.deleteEntry(entry) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.hubAccentRed.opacity(0.7))
                        .padding(8)
                        .background(Color.hubAccentRed.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(HubLayout.standardPadding)
        }
    }

    private func statusColor(_ status: DoseStatus) -> Color {
        switch status {
        case .taken: return Color.hubAccentGreen
        case .missed: return Color.hubAccentRed
        case .skipped: return Color.hubAccentYellow
        case .delayed: return Color.hubPrimary
        }
    }
}