import SwiftUI

// MARK: - Toolkit Home View

/// Main toolkit grid displaying plugin cards in a 2-column layout.
/// Each card navigates to a specific plugin module.
struct ToolkitHomeView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: CortexLayout.itemSpacing),
        GridItem(.flexible(), spacing: CortexLayout.itemSpacing)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: CortexLayout.itemSpacing) {
                    ForEach(ToolkitPlugin.allCases) { plugin in
                        NavigationLink(destination: plugin.destination) {
                            ToolkitPluginCard(plugin: plugin)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(CortexLayout.standardPadding)
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationTitle(L10n.toolkitTitle)
        }
    }
}

// MARK: - Plugin Card

/// A single plugin card in the toolkit grid.
private struct ToolkitPluginCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let plugin: ToolkitPlugin

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: plugin.icon)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(plugin.iconColor)
                .frame(height: 40)

            VStack(spacing: 4) {
                Text(plugin.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text(plugin.subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, CortexLayout.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: CortexLayout.cardCornerRadius)
                .fill(AdaptiveColors.surface(for: colorScheme))
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.3)
                        : Color.black.opacity(0.06),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
    }
}

// MARK: - Plugin Definition

/// All available toolkit plugins.
enum ToolkitPlugin: String, CaseIterable, Identifiable {
    case bookFactory
    case fluent
    case parking
    case calendar
    case health

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bookFactory: return L10n.toolkitBookFactory
        case .fluent: return L10n.toolkitFluent
        case .parking: return L10n.toolkitParking
        case .calendar: return L10n.toolkitCalendar
        case .health: return L10n.toolkitHealth
        }
    }

    var subtitle: String {
        switch self {
        case .bookFactory: return L10n.toolkitBookFactoryDesc
        case .fluent: return L10n.toolkitFluentDesc
        case .parking: return L10n.toolkitParkingDesc
        case .calendar: return L10n.toolkitCalendarDesc
        case .health: return L10n.toolkitHealthDesc
        }
    }

    var icon: String {
        switch self {
        case .bookFactory: return "book.fill"
        case .fluent: return "textformat.abc"
        case .parking: return "car.fill"
        case .calendar: return "calendar"
        case .health: return "heart.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .bookFactory: return .cortexPrimary
        case .fluent: return .cortexPrimaryLight
        case .parking: return .cortexAccentGreen
        case .calendar: return .cortexAccentYellow
        case .health: return .cortexAccentRed
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .bookFactory: BookFactoryView()
        case .fluent: FluentView()
        case .parking: ParkingView()
        case .calendar: CalendarPluginView()
        case .health: HealthView()
        }
    }
}

// MARK: - Preview

#Preview {
    ToolkitHomeView()
}
