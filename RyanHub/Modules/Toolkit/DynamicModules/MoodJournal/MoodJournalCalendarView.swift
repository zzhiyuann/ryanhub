import SwiftUI

// MARK: - MoodJournal Calendar View

struct MoodJournalCalendarView: View {
    let viewModel: MoodJournalViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDate: Date?

    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                monthNavigationHeader
                weekdayHeaderRow
                calendarGrid
                if let date = selectedDate {
                    expandedDaySection(for: date)
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Month Navigation

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.goToPreviousMonth()
                    selectedDate = nil
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.hubPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.hubPrimary.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            Text(viewModel.displayedMonthTitle)
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.goToNextMonth()
                    selectedDate = nil
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.hubPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.hubPrimary.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Weekday Header

    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            ForEach(reorderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var reorderedWeekdaySymbols: [String] {
        let firstWeekday = calendar.firstWeekday
        let symbols = weekdaySymbols
        let index = firstWeekday - 1
        return Array(symbols[index...]) + Array(symbols[..<index])
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let moodMap = viewModel.moodMapForDisplayedMonth()
        let days = generateDaysForMonth()

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(days, id: \.self) { day in
                if let day = day {
                    dayCell(for: day, moodMap: moodMap)
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func dayCell(for date: Date, moodMap: [Date: Double]) -> some View {
        let dayNumber = calendar.component(.day, from: date)
        let mood = moodMap[calendar.startOfDay(for: date)]
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isSelected {
                    selectedDate = nil
                } else {
                    selectedDate = date
                }
            }
        } label: {
            Text("\(dayNumber)")
                .font(.system(size: 14, weight: isToday ? .bold : .medium))
                .foregroundStyle(dayCellTextColor(mood: mood, isSelected: isSelected))
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(dayCellBackground(mood: mood))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.hubPrimary : (isToday ? Color.hubPrimary.opacity(0.5) : Color.clear), lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day Cell Colors

    private func dayCellBackground(mood: Double?) -> Color {
        guard let mood = mood else {
            return colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)
        }
        return moodColor(for: mood).opacity(0.3)
    }

    private func dayCellTextColor(mood: Double?, isSelected: Bool) -> Color {
        if isSelected {
            return AdaptiveColors.textPrimary(for: colorScheme)
        }
        if mood != nil {
            return AdaptiveColors.textPrimary(for: colorScheme)
        }
        return AdaptiveColors.textSecondary(for: colorScheme)
    }

    /// Maps mood rating 1-10 to a gradient: red (1) → yellow (5) → green (10)
    private func moodColor(for rating: Double) -> Color {
        let clamped = min(max(rating, 1.0), 10.0)
        if clamped <= 5.0 {
            // Red to Yellow: 1 → 5
            let t = (clamped - 1.0) / 4.0
            return blend(from: Color.hubAccentRed, to: Color.hubAccentYellow, fraction: t)
        } else {
            // Yellow to Green: 5 → 10
            let t = (clamped - 5.0) / 5.0
            return blend(from: Color.hubAccentYellow, to: Color.hubAccentGreen, fraction: t)
        }
    }

    private func blend(from: Color, to: Color, fraction: Double) -> Color {
        let f = min(max(fraction, 0), 1)
        let fromComponents = UIColor(from).rgba
        let toComponents = UIColor(to).rgba
        return Color(
            red: fromComponents.red + (toComponents.red - fromComponents.red) * f,
            green: fromComponents.green + (toComponents.green - fromComponents.green) * f,
            blue: fromComponents.blue + (toComponents.blue - fromComponents.blue) * f
        )
    }

    // MARK: - Expanded Day Section

    private func expandedDaySection(for date: Date) -> some View {
        let dayEntries = viewModel.entriesForDate(date)
        let formatter = DateFormatter()
        formatter.dateStyle = .long

        return VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: formatter.string(from: date))

            if dayEntries.isEmpty {
                HubCard {
                    HStack {
                        Image(systemName: "moon.zzz")
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Text("No entries for this day")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, HubLayout.itemSpacing)
                }
            } else {
                ForEach(dayEntries) { entry in
                    HubCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: entry.emotion.icon)
                                    .foregroundStyle(moodColor(for: Double(entry.rating)))
                                    .font(.system(size: 18))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.emotion.displayName)
                                        .font(.hubBody)
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                    Text(entry.timeString)
                                        .font(.hubCaption)
                                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                }

                                Spacer()

                                moodBadge(rating: entry.rating)
                            }

                            if entry.hasNotes {
                                Text(entry.notes)
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                    .lineLimit(3)
                            }
                        }
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func moodBadge(rating: Int) -> some View {
        Text("\(rating)")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                Circle()
                    .fill(moodColor(for: Double(rating)))
            )
    }

    // MARK: - Date Generation

    private func generateDaysForMonth() -> [Date?] {
        let components = calendar.dateComponents([.year, .month], from: viewModel.displayedMonth)
        guard let monthStart = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }

        // Pad to complete the last row
        let remainder = days.count % 7
        if remainder > 0 {
            days.append(contentsOf: Array(repeating: nil as Date?, count: 7 - remainder))
        }

        return days
    }
}

// MARK: - UIColor RGBA Helper

private extension UIColor {
    var rgba: (red: Double, green: Double, blue: Double, alpha: Double) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}