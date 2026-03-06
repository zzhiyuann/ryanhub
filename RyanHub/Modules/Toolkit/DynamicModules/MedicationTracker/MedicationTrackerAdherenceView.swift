import SwiftUI

struct MedicationTrackerAdherenceView: View {
    let viewModel: MedicationTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDay: Date?

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                streakSection
                calendarHeatmapSection
                perMedicationSection
                weeklyTrendSection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Section 1: Streak Display

    private var streakSection: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Streaks")
            StreakCounter(
                currentStreak: viewModel.currentStreak,
                longestStreak: viewModel.longestStreak,
                unit: "days",
                isActiveToday: !viewModel.todayEntries.isEmpty
            )
        }
    }

    // MARK: - Section 2: Calendar Heatmap

    private var calendarHeatmapSection: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "30-Day Adherence")
            HubCard {
                VStack(spacing: HubLayout.itemSpacing) {
                    weekdayHeaders
                    calendarGrid
                    heatmapLegend
                    if let selectedDay {
                        dayBreakdownView(for: selectedDay)
                    }
                }
                .padding(HubLayout.standardPadding)
            }
        }
    }

    private var weekdayHeaders: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return HStack(spacing: 4) {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let days = calendarDays
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, dayInfo in
                if let date = dayInfo.date {
                    let rate = adherenceRate(for: date)
                    let hasData = dayHasData(date)
                    dayCell(date: date, rate: rate, hasData: hasData)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDay = selectedDay == date ? nil : date
                            }
                        }
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func dayCell(date: Date, rate: Double, hasData: Bool) -> some View {
        let isSelected = selectedDay == date
        let isToday = calendar.isDateInToday(date)
        return RoundedRectangle(cornerRadius: 4)
            .fill(cellColor(rate: rate, hasData: hasData))
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Group {
                    if isToday {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.hubPrimary, lineWidth: 2)
                    }
                }
            )
            .overlay(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(AdaptiveColors.textPrimary(for: colorScheme), lineWidth: 2)
                    }
                }
            )
            .overlay(
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(cellTextColor(rate: rate, hasData: hasData))
            )
    }

    private func cellColor(rate: Double, hasData: Bool) -> Color {
        guard hasData else {
            return colorScheme == .dark
                ? Color.gray.opacity(0.15)
                : Color.gray.opacity(0.1)
        }
        if rate >= 1.0 {
            return Color.hubAccentGreen.opacity(0.8)
        } else if rate > 0 {
            return Color.hubAccentYellow.opacity(0.7)
        } else {
            return Color.hubAccentRed.opacity(0.6)
        }
    }

    private func cellTextColor(rate: Double, hasData: Bool) -> Color {
        guard hasData, rate > 0 else {
            return AdaptiveColors.textSecondary(for: colorScheme)
        }
        return .white
    }

    private var heatmapLegend: some View {
        HStack(spacing: HubLayout.itemSpacing) {
            legendItem(color: Color.hubAccentGreen.opacity(0.8), label: "100%")
            legendItem(color: Color.hubAccentYellow.opacity(0.7), label: "Partial")
            legendItem(color: Color.hubAccentRed.opacity(0.6), label: "Missed")
            legendItem(
                color: colorScheme == .dark ? Color.gray.opacity(0.15) : Color.gray.opacity(0.1),
                label: "No data"
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
    }

    private func dayBreakdownView(for date: Date) -> some View {
        let taken = entriesForDay(date)
        let takenNames = Set(taken.map { $0.name })
        let missed = activeMedicationNames.filter { !takenNames.contains($0) }
        let displayFmt = DateFormatter()
        displayFmt.dateStyle = .medium

        return VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text(displayFmt.string(from: date))
                .font(.hubBody)
                .fontWeight(.semibold)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            if taken.isEmpty && missed.isEmpty {
                Text("No medication data for this day.")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            if !taken.isEmpty {
                ForEach(taken) { entry in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.hubAccentGreen)
                            .font(.system(size: 14))
                        Text("\(entry.name) \(entry.dosage)")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Spacer()
                    }
                }
            }

            if !missed.isEmpty {
                ForEach(missed, id: \.self) { name in
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.hubAccentRed)
                            .font(.system(size: 14))
                        Text(name)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Spacer()
                        Text("Missed")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.hubAccentRed)
                    }
                }
            }
        }
    }

    // MARK: - Section 3: Per-Medication Adherence

    private var perMedicationSection: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Per-Medication Adherence")

            if medicationAdherenceRanked.isEmpty {
                HubCard {
                    Text("No medication data yet.")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(HubLayout.standardPadding)
                }
            } else {
                HubCard {
                    VStack(spacing: 12) {
                        ForEach(
                            Array(medicationAdherenceRanked.enumerated()),
                            id: \.element.name
                        ) { index, med in
                            medicationBar(med: med, isLowest: index == 0 && med.rate < 0.8)
                        }
                    }
                    .padding(HubLayout.standardPadding)
                }
            }
        }
    }

    private func medicationBar(
        med: (name: String, rate: Double, color: Color),
        isLowest: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if isLowest {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.hubAccentYellow)
                }
                Text(med.name)
                    .font(.hubCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(
                        isLowest
                            ? Color.hubAccentRed
                            : AdaptiveColors.textPrimary(for: colorScheme)
                    )
                Spacer()
                Text("\(Int(med.rate * 100))%")
                    .font(.hubCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(barColor(for: med.rate))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            colorScheme == .dark
                                ? Color.gray.opacity(0.2)
                                : Color.gray.opacity(0.12)
                        )
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor(for: med.rate))
                        .frame(width: geo.size.width * max(med.rate, 0))
                }
            }
            .frame(height: 8)
        }
    }

    private func barColor(for rate: Double) -> Color {
        if rate >= 0.9 { return Color.hubAccentGreen }
        if rate >= 0.7 { return Color.hubAccentYellow }
        return Color.hubAccentRed
    }

    // MARK: - Section 4: Weekly Trend

    private var weeklyTrendSection: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Weekly Trend")
            ModuleChartView(
                title: "Doses Logged",
                subtitle: weeklyComparisonText,
                dataPoints: viewModel.weeklyChartData,
                style: .bar,
                color: Color.hubPrimary
            )
        }
    }

    // MARK: - Data Computation

    private var activeMedicationNames: [String] {
        let active = viewModel.entries.filter { $0.isActive }
        let names = Set(active.map { $0.name })
        return Array(names).sorted()
    }

    private struct CalendarDay {
        let date: Date?
    }

    private var calendarDays: [CalendarDay] {
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -29, to: today) else {
            return []
        }
        let startWeekday = calendar.component(.weekday, from: startDate)
        let leadingBlanks = startWeekday - calendar.firstWeekday
        let adjusted = leadingBlanks >= 0 ? leadingBlanks : leadingBlanks + 7

        var days: [CalendarDay] = []
        for _ in 0..<adjusted {
            days.append(CalendarDay(date: nil))
        }
        for offset in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: offset, to: startDate) {
                days.append(CalendarDay(date: date))
            }
        }
        return days
    }

    private func adherenceRate(for date: Date) -> Double {
        let totalMeds = activeMedicationNames.count
        guard totalMeds > 0 else { return 0 }
        let dayStr = dateFormatter.string(from: date)
        let dayEntries = viewModel.entries.filter { $0.date.hasPrefix(dayStr) }
        let uniqueTaken = Set(dayEntries.map { $0.name }).count
        return Double(uniqueTaken) / Double(totalMeds)
    }

    private func dayHasData(_ date: Date) -> Bool {
        guard !activeMedicationNames.isEmpty else { return false }
        let dayStr = dateFormatter.string(from: date)
        return viewModel.entries.contains { $0.date.hasPrefix(dayStr) }
    }

    private func entriesForDay(_ date: Date) -> [MedicationTrackerEntry] {
        let dayStr = dateFormatter.string(from: date)
        return viewModel.entries.filter { $0.date.hasPrefix(dayStr) }
    }

    private var medicationAdherenceRanked: [(name: String, rate: Double, color: Color)] {
        let today = calendar.startOfDay(for: Date())
        return activeMedicationNames.map { name in
            var daysLogged = 0
            for offset in 0..<30 {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                    continue
                }
                let dayStr = dateFormatter.string(from: day)
                if viewModel.entries.contains(where: {
                    $0.name == name && $0.date.hasPrefix(dayStr)
                }) {
                    daysLogged += 1
                }
            }
            let rate = Double(daysLogged) / 30.0
            let entryColor = viewModel.entries
                .first(where: { $0.name == name })?.colorValue ?? .blue
            return (name: name, rate: rate, color: entryColor)
        }.sorted { $0.rate < $1.rate }
    }

    private var weeklyComparisonText: String {
        let today = calendar.startOfDay(for: Date())
        let thisWeekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        let lastWeekStart = calendar.date(byAdding: .day, value: -13, to: today)!
        let lastWeekEnd = calendar.date(byAdding: .day, value: -7, to: today)!

        let thisWeekCount = viewModel.entries.filter { entry in
            guard let d = parseDatePrefix(entry.date) else { return false }
            let day = calendar.startOfDay(for: d)
            return day >= thisWeekStart && day <= today
        }.count

        let lastWeekCount = viewModel.entries.filter { entry in
            guard let d = parseDatePrefix(entry.date) else { return false }
            let day = calendar.startOfDay(for: d)
            return day >= lastWeekStart && day <= lastWeekEnd
        }.count

        if lastWeekCount == 0 {
            return "This week: \(thisWeekCount) doses"
        }
        let change = thisWeekCount - lastWeekCount
        if change > 0 {
            return "+\(change) vs last week"
        } else if change < 0 {
            return "\(change) vs last week"
        }
        return "Same as last week"
    }

    private func parseDatePrefix(_ dateStr: String) -> Date? {
        dateFormatter.date(from: String(dateStr.prefix(10)))
    }
}