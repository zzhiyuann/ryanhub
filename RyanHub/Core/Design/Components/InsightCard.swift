import SwiftUI

// MARK: - Insight Card

/// Displays an AI-generated or computed insight with contextual styling.
/// Use for analytics views to surface patterns and recommendations.
struct InsightCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let insight: ModuleInsight

    var body: some View {
        HubCard {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                Image(systemName: insight.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(insight.type.color)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(insight.type.color.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Text(insight.message)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Module Insight

struct ModuleInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let message: String
}

enum InsightType {
    case trend
    case achievement
    case suggestion
    case warning

    var icon: String {
        switch self {
        case .trend: return "chart.line.uptrend.xyaxis"
        case .achievement: return "star.fill"
        case .suggestion: return "lightbulb.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .trend: return .hubPrimary
        case .achievement: return .hubAccentYellow
        case .suggestion: return .hubAccentGreen
        case .warning: return .hubAccentRed
        }
    }
}

// MARK: - Insights List

/// A vertical stack of InsightCards.
struct InsightsList: View {
    let insights: [ModuleInsight]

    var body: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            ForEach(insights) { insight in
                InsightCard(insight: insight)
            }
        }
    }
}
