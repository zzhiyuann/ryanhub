import SwiftUI

// MARK: - Calendar Heatmap

/// A GitHub-style heatmap showing daily activity over the past weeks.
/// Each cell represents a day, colored by activity intensity.
struct CalendarHeatmap: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let data: [Date: Double]
    let color: Color
    let weeks: Int

    init(
        title: String = "Activity",
        data: [Date: Double],
        color: Color = .hubPrimary,
        weeks: Int = 12
    ) {
        self.title = title
        self.data = data
        self.color = color
        self.weeks = weeks
    }

    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3
    private let daysInWeek = 7

    private var maxValue: Double {
        data.values.max() ?? 1
    }

    private var calendarDays: [[Date?]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let totalDays = weeks * 7

        guard let startDate = calendar.date(byAdding: .day, value: -(totalDays - 1), to: today) else {
            return []
        }

        // Build a grid: columns = weeks, rows = weekdays (Mon-Sun)
        var grid: [[Date?]] = Array(repeating: Array(repeating: nil, count: daysInWeek), count: weeks)

        for dayOffset in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let weekday = (calendar.component(.weekday, from: date) + 5) % 7 // Mon=0
            let weekIndex = dayOffset / 7
            if weekIndex < weeks {
                grid[weekIndex][weekday] = date
            }
        }

        return grid
    }

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Spacer()

                    // Legend
                    HStack(spacing: 2) {
                        Text("Less")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        ForEach(0..<5) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(cellColor(for: Double(level) / 4.0))
                                .frame(width: 10, height: 10)
                        }
                        Text("More")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }

                // Weekday labels + grid
                HStack(alignment: .top, spacing: cellSpacing) {
                    // Weekday labels
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { row in
                            if row % 2 == 0 {
                                Text(weekdayLabel(row))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                    .frame(width: 20, height: cellSize)
                            } else {
                                Color.clear.frame(width: 20, height: cellSize)
                            }
                        }
                    }

                    // Grid
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: cellSpacing) {
                            ForEach(0..<calendarDays.count, id: \.self) { week in
                                VStack(spacing: cellSpacing) {
                                    ForEach(0..<daysInWeek, id: \.self) { day in
                                        if let date = calendarDays[week][day] {
                                            let calendar = Calendar.current
                                            let normalized = calendar.startOfDay(for: date)
                                            let value = data[normalized] ?? 0
                                            let intensity = maxValue > 0 ? value / maxValue : 0

                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(cellColor(for: intensity))
                                                .frame(width: cellSize, height: cellSize)
                                        } else {
                                            Color.clear
                                                .frame(width: cellSize, height: cellSize)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Summary
                let activeDays = data.filter { $0.value > 0 }.count
                Text("\(activeDays) active days in the last \(weeks) weeks")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func cellColor(for intensity: Double) -> Color {
        if intensity <= 0 {
            return AdaptiveColors.surfaceSecondary(for: colorScheme)
        }
        return color.opacity(0.2 + intensity * 0.8)
    }

    private func weekdayLabel(_ index: Int) -> String {
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        return labels[index]
    }
}
