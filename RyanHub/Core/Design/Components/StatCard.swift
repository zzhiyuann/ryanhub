import SwiftUI

// MARK: - Stat Card

/// Displays a single metric with an optional trend indicator.
/// Use in dashboard layouts to show key statistics at a glance.
struct StatCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let value: String
    let icon: String
    let trend: StatTrend?
    let color: Color

    init(
        title: String,
        value: String,
        icon: String = "chart.bar.fill",
        trend: StatTrend? = nil,
        color: Color = .hubPrimary
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.trend = trend
        self.color = color
    }

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(color.opacity(0.12))
                        )

                    Spacer()

                    if let trend {
                        trendBadge(trend)
                    }
                }

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .lineLimit(1)
            }
        }
    }

    private func trendBadge(_ trend: StatTrend) -> some View {
        HStack(spacing: 2) {
            Image(systemName: trend.direction == .up ? "arrow.up" : "arrow.down")
                .font(.system(size: 8, weight: .bold))
            Text(trend.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(trend.direction == .up
                    ? (trend.isPositive ? Color.hubAccentGreen : Color.hubAccentRed)
                    : (trend.isPositive ? Color.hubAccentGreen : Color.hubAccentRed)
                )
                .opacity(0.15)
        )
        .foregroundStyle(
            trend.isPositive ? Color.hubAccentGreen : Color.hubAccentRed
        )
    }
}

// MARK: - Stat Trend

struct StatTrend {
    let label: String
    let direction: TrendDirection
    let isPositive: Bool

    enum TrendDirection {
        case up, down
    }

    /// Quick constructor: positive value = up+good, negative = down+bad (default assumption).
    /// Override isPositive for metrics where down is good (e.g., screen time, spending).
    static func from(change: Double, format: String = "%.1f", invertPositive: Bool = false) -> StatTrend? {
        guard change != 0 else { return nil }
        let dir: TrendDirection = change > 0 ? .up : .down
        let positive = invertPositive ? (change < 0) : (change > 0)
        return StatTrend(
            label: String(format: format, abs(change)),
            direction: dir,
            isPositive: positive
        )
    }
}

// MARK: - Stat Grid

/// A 2-column grid layout for StatCards.
struct StatGrid<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: HubLayout.itemSpacing),
                GridItem(.flexible(), spacing: HubLayout.itemSpacing)
            ],
            spacing: HubLayout.itemSpacing
        ) {
            content()
        }
    }
}
