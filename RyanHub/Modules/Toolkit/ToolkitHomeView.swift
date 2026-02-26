import SwiftUI

// MARK: - Toolkit Home View

/// Main toolkit view with a macOS-style menu bar at the top.
/// The menu bar provides instant tool switching, while the content area below
/// displays either the home grid ("desktop") or the selected tool's full view.
/// This creates a "world within a world" experience inside the Toolkit tab.
struct ToolkitHomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var selectedPlugin: ToolkitPlugin?
    @State private var menuBarAppeared = false
    @Namespace private var menuAnimation

    var body: some View {
        VStack(spacing: 0) {
            // macOS-style menu bar — always visible at top
            ToolkitMenuBar(
                selectedPlugin: $selectedPlugin,
                namespace: menuAnimation,
                appeared: menuBarAppeared
            )

            // Content area: selected tool or home grid
            ZStack {
                AdaptiveColors.background(for: colorScheme)
                    .ignoresSafeArea(edges: .bottom)

                if let plugin = selectedPlugin {
                    toolContent(for: plugin)
                        .id(plugin)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                } else {
                    ToolkitDesktopGrid(selectedPlugin: $selectedPlugin)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: selectedPlugin)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                menuBarAppeared = true
            }
        }
        .onChange(of: selectedPlugin) { _, newValue in
            appState.isInToolkitModule = newValue != nil
        }
    }

    // MARK: - Tool Content

    /// Returns the content view for each tool. Only tools that use `.toolbar`
    /// items are wrapped in NavigationStack (Calendar). Others render
    /// directly to avoid redundant navigation chrome.
    @ViewBuilder
    private func toolContent(for plugin: ToolkitPlugin) -> some View {
        switch plugin {
        case .bookFactory:
            BookFactoryView()
        case .fluent:
            FluentView()
        case .parking:
            ParkingView()
        case .calendar:
            NavigationStack {
                CalendarPluginView()
            }
        case .health:
            HealthView()
        }
    }
}

// MARK: - Menu Bar

/// A macOS-style menu bar that sits at the top of the Toolkit tab.
/// Features: frosted glass background, horizontally scrollable tool items,
/// a home/grid button on the left, and smooth selection indicators.
struct ToolkitMenuBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedPlugin: ToolkitPlugin?
    var namespace: Namespace.ID
    var appeared: Bool

    /// Height of the menu bar content area (excluding divider).
    private let barHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Home / grid icon on the left
                homeButton
                    .padding(.leading, 12)

                // Thin vertical divider
                divider
                    .padding(.horizontal, 8)

                // Scrollable tool items
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(ToolkitPlugin.allCases) { plugin in
                            menuItem(for: plugin)
                        }
                    }
                    .padding(.trailing, 12)
                }
            }
            .frame(height: barHeight)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                // Subtle bottom border
                AdaptiveColors.border(for: colorScheme)
                    .frame(height: 0.5)
            }
        }
        .accessibilityIdentifier(AccessibilityID.toolkitMenuBar)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
    }

    // MARK: - Home Button

    private var homeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedPlugin = nil
            }
        } label: {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    selectedPlugin == nil
                        ? Color.hubPrimary
                        : AdaptiveColors.textSecondary(for: colorScheme)
                )
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            selectedPlugin == nil
                                ? Color.hubPrimary.opacity(0.12)
                                : Color.clear
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.toolkitMenuHome)
    }

    // MARK: - Vertical Divider

    private var divider: some View {
        Rectangle()
            .fill(AdaptiveColors.border(for: colorScheme))
            .frame(width: 1, height: 24)
    }

    // MARK: - Menu Item

    private func menuItem(for plugin: ToolkitPlugin) -> some View {
        let isSelected = selectedPlugin == plugin

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedPlugin = plugin
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: plugin.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        isSelected ? plugin.iconColor : AdaptiveColors.textSecondary(for: colorScheme)
                    )

                Text(plugin.shortName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(
                        isSelected
                            ? AdaptiveColors.textPrimary(for: colorScheme)
                            : AdaptiveColors.textSecondary(for: colorScheme)
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(plugin.iconColor.opacity(0.12))
                            .matchedGeometryEffect(id: "menuHighlight", in: namespace)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.toolkitMenuItem(plugin.rawValue))
    }
}

// MARK: - Desktop Grid

/// The "desktop" view showing all toolkit plugins in a 2-column card grid.
/// Tapping a card selects it in the menu bar and opens it in-place.
struct ToolkitDesktopGrid: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedPlugin: ToolkitPlugin?

    private let columns = [
        GridItem(.flexible(), spacing: HubLayout.itemSpacing),
        GridItem(.flexible(), spacing: HubLayout.itemSpacing)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HubLayout.sectionSpacing) {
                // Title header
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.toolkitTitle)
                        .font(.hubTitle)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Text("Your personal toolkit")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
                .padding(.top, 8)

                // Plugin grid
                LazyVGrid(columns: columns, spacing: HubLayout.itemSpacing) {
                    ForEach(ToolkitPlugin.allCases) { plugin in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedPlugin = plugin
                            }
                        } label: {
                            ToolkitPluginCard(plugin: plugin)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(AccessibilityID.toolkitCard(plugin.rawValue))
                    }
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .accessibilityIdentifier(AccessibilityID.toolkitDesktopGrid)
    }
}

// MARK: - Plugin Card

/// A single plugin card in the toolkit desktop grid.
private struct ToolkitPluginCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let plugin: ToolkitPlugin

    var body: some View {
        VStack(spacing: 12) {
            // Icon with tinted background circle
            ZStack {
                Circle()
                    .fill(plugin.iconColor.opacity(0.12))
                    .frame(width: 52, height: 52)

                Image(systemName: plugin.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(plugin.iconColor)
            }

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
        .padding(.horizontal, HubLayout.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
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

    /// Short name for the menu bar (compact).
    var shortName: String {
        switch self {
        case .bookFactory: return "Books"
        case .fluent: return "Fluent"
        case .parking: return "Parking"
        case .calendar: return "Calendar"
        case .health: return "Health"
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
        case .bookFactory: return .hubPrimary
        case .fluent: return .hubPrimaryLight
        case .parking: return .hubAccentGreen
        case .calendar: return .hubAccentYellow
        case .health: return .hubAccentRed
        }
    }
}

// MARK: - Preview

#Preview {
    ToolkitHomeView()
}
