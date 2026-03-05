import SwiftUI
import Charts

// MARK: - Module Chart View

/// A reusable chart component for dynamic modules.
/// Supports line, area, and bar chart styles with the Ryan Hub design system.
struct ModuleChartView: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String?
    let dataPoints: [ChartDataPoint]
    let style: ChartStyle
    let color: Color
    let showArea: Bool

    @State private var selectedPoint: ChartDataPoint?

    init(
        title: String,
        subtitle: String? = nil,
        dataPoints: [ChartDataPoint],
        style: ChartStyle = .line,
        color: Color = .hubPrimary,
        showArea: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.dataPoints = dataPoints
        self.style = style
        self.color = color
        self.showArea = showArea
    }

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                headerView

                if let selected = selectedPoint {
                    tooltipView(for: selected)
                }

                if dataPoints.count >= 2 {
                    chartContent
                        .frame(height: 180)
                        .clipped()
                } else {
                    placeholderView
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                if let subtitle {
                    Text(subtitle)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }

            Spacer()

            if let last = dataPoints.last, let prev = dataPoints.dropLast().last {
                trendIndicator(current: last.value, previous: prev.value)
            }
        }
    }

    private func trendIndicator(current: Double, previous: Double) -> some View {
        let change = current - previous
        let pct = previous != 0 ? (change / previous) * 100 : 0
        let isUp = change >= 0
        return HStack(spacing: 2) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text(String(format: "%+.1f%%", pct))
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(isUp ? Color.hubAccentGreen : Color.hubAccentRed)
    }

    // MARK: - Chart

    private var chartContent: some View {
        Chart {
            switch style {
            case .line:
                lineChartMarks
            case .bar:
                barChartMarks
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(AdaptiveColors.border(for: colorScheme))
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
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
                    if let v = value.as(Double.self) {
                        Text(Self.formatAxisValue(v))
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
                        handleTap(at: location, proxy: proxy, geometry: geometry)
                    }
            }
        }
    }

    @ChartContentBuilder
    private var lineChartMarks: some ChartContent {
        if showArea {
            ForEach(dataPoints) { point in
                AreaMark(
                    x: .value("Label", point.label),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }

        ForEach(dataPoints) { point in
            LineMark(
                x: .value("Label", point.label),
                y: .value("Value", point.value)
            )
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
        }

        ForEach(dataPoints) { point in
            PointMark(
                x: .value("Label", point.label),
                y: .value("Value", point.value)
            )
            .foregroundStyle(
                selectedPoint?.id == point.id ? color : color.opacity(0.7)
            )
            .symbolSize(selectedPoint?.id == point.id ? 60 : 25)
        }

        if let selected = selectedPoint {
            RuleMark(x: .value("Label", selected.label))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }

    @ChartContentBuilder
    private var barChartMarks: some ChartContent {
        ForEach(dataPoints) { point in
            BarMark(
                x: .value("Label", point.label),
                y: .value("Value", point.value)
            )
            .foregroundStyle(
                selectedPoint?.id == point.id
                    ? color
                    : color.opacity(0.7)
            )
            .cornerRadius(4)
        }
    }

    // MARK: - Tooltip

    private func tooltipView(for point: ChartDataPoint) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(Self.formatValue(point.value))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text(point.label)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.15)) { selectedPoint = nil }
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

    // MARK: - Placeholder

    private var placeholderView: some View {
        Text("Add more entries to see the chart")
            .font(.hubBody)
            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 180)
    }

    // MARK: - Interaction

    private func handleTap(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let frame = geometry[plotFrame]
        let relativeX = location.x - frame.origin.x
        guard let label: String = proxy.value(atX: relativeX) else { return }

        let tapped = dataPoints.first { $0.label == label }
        withAnimation(.easeOut(duration: 0.15)) {
            selectedPoint = (selectedPoint?.id == tapped?.id) ? nil : tapped
        }
    }

    // MARK: - Formatting

    private static func formatValue(_ value: Double) -> String {
        if value == value.rounded() && value < 10000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private static func formatAxisValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }
}

// MARK: - Supporting Types

struct ChartDataPoint: Identifiable {
    let id: String
    let label: String
    let value: Double

    init(label: String, value: Double) {
        self.id = label
        self.label = label
        self.value = value
    }
}

enum ChartStyle {
    case line
    case bar
}
