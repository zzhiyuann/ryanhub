import SwiftUI
import Charts

// MARK: - Weight Timeline Chart

/// Interactive weight timeline chart showing up to 30 data points.
/// Supports tapping on individual points to see exact weight + date.
struct WeightTimelineChart: View {
    @Environment(\.colorScheme) private var colorScheme
    let entries: [WeightEntry]
    let weightRange: (min: Double, max: Double)?

    @State private var selectedEntry: WeightEntry?

    private var sortedEntries: [WeightEntry] {
        entries.sorted { $0.date < $1.date }
    }

    /// Normalize a date to start-of-day so data points align precisely with x-axis labels.
    private func chartDate(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weight Timeline")
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        Text("\(entries.count) entries")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    // Min/Max labels
                    if let range = weightRange {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 10, weight: .bold))
                                Text(String(format: "%.1f", range.max))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color.hubAccentRed.opacity(0.8))

                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 10, weight: .bold))
                                Text(String(format: "%.1f", range.min))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color.hubAccentGreen.opacity(0.8))
                        }
                    }
                }

                // Selected entry tooltip
                if let selected = selectedEntry {
                    selectedEntryTooltip(selected)
                }

                // Chart
                if sortedEntries.count >= 2 {
                    chartView
                        .frame(height: 200)
                        .clipped()
                } else {
                    Text("Log at least 2 entries to see the timeline")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 200)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Chart View

    private var chartView: some View {
        Chart {
            // Area gradient under the line
            ForEach(sortedEntries) { entry in
                AreaMark(
                    x: .value("Date", chartDate(entry.date)),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.hubPrimary.opacity(0.3),
                            Color.hubPrimary.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Main line
            ForEach(sortedEntries) { entry in
                LineMark(
                    x: .value("Date", chartDate(entry.date)),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(Color.hubPrimary)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }

            // Data points
            ForEach(sortedEntries) { entry in
                PointMark(
                    x: .value("Date", chartDate(entry.date)),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(
                    selectedEntry?.id == entry.id
                        ? Color.hubAccentRed
                        : isLatestEntry(entry) ? Color.hubPrimary : Color.hubPrimary.opacity(0.7)
                )
                .symbolSize(selectedEntry?.id == entry.id ? 80 : (isLatestEntry(entry) ? 60 : 30))
            }

            // Selection rule mark
            if let selected = selectedEntry {
                RuleMark(x: .value("Date", chartDate(selected.date)))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: xAxisDates) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(AdaptiveColors.border(for: colorScheme))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatAxisDate(date))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(AdaptiveColors.border(for: colorScheme))
                AxisValueLabel {
                    if let weight = value.as(Double.self) {
                        Text(String(format: "%.0f", weight))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleChartTap(at: location, proxy: proxy, geometry: geometry)
                    }
            }
        }
    }

    // MARK: - Y Domain

    private var yDomain: ClosedRange<Double> {
        if let range = weightRange {
            return range.min...range.max
        }
        let weights = sortedEntries.map(\.weight)
        let minW = (weights.min() ?? 0) - 1
        let maxW = (weights.max() ?? 100) + 1
        return minW...maxW
    }

    // MARK: - Helpers

    /// Evenly-spaced dates from actual data entries for x-axis labels.
    /// Using real data dates ensures labels sit exactly on data points.
    private var xAxisDates: [Date] {
        let dates = sortedEntries.map { chartDate($0.date) }
        let unique = Array(Set(dates)).sorted()
        let desiredCount = min(unique.count, 6)
        guard desiredCount >= 2 else { return unique }
        // Pick evenly spaced indices including first and last
        var selected: [Date] = []
        for i in 0..<desiredCount {
            let index = i * (unique.count - 1) / (desiredCount - 1)
            selected.append(unique[index])
        }
        return selected
    }

    private func isLatestEntry(_ entry: WeightEntry) -> Bool {
        entry.id == sortedEntries.last?.id
    }

    private func formatAxisDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func selectedEntryTooltip(_ entry: WeightEntry) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.hubPrimary)
                .frame(width: 8, height: 8)

            Text(entry.formattedWeight)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text(entry.formattedDate)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            if let note = entry.note, !note.isEmpty {
                Text("— \(note)")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    selectedEntry = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func handleChartTap(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let plotFrame = geometry[proxy.plotFrame!]
        let relativeX = location.x - plotFrame.origin.x

        guard let tappedDate: Date = proxy.value(atX: relativeX) else { return }

        // Find the closest entry to the tapped date using normalized chart dates
        let closest = sortedEntries.min(by: {
            abs(chartDate($0.date).timeIntervalSince(tappedDate)) < abs(chartDate($1.date).timeIntervalSince(tappedDate))
        })

        withAnimation(.easeOut(duration: 0.15)) {
            if selectedEntry?.id == closest?.id {
                selectedEntry = nil
            } else {
                selectedEntry = closest
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let entries = (0..<15).map { i in
        WeightEntry(
            date: Calendar.current.date(byAdding: .day, value: -14 + i, to: Date())!,
            weight: 92.0 - Double(i) * 0.15 + Double.random(in: -0.3...0.3)
        )
    }

    ScrollView {
        WeightTimelineChart(
            entries: entries,
            weightRange: (min: 89.0, max: 93.0)
        )
        .padding()
    }
    .background(Color(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x0F / 255.0))
}
