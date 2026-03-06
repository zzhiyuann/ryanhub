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
    @State private var selectedDynamicModule: String?
    @State private var menuBarAppeared = false
    @State private var pluginOrder: [ToolkitPlugin] = ToolkitPlugin.loadOrder()
    @Namespace private var menuAnimation

    /// Whether any module (static or dynamic) is selected.
    private var hasSelection: Bool {
        selectedPlugin != nil || selectedDynamicModule != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // macOS-style menu bar — always visible at top
            ToolkitMenuBar(
                selectedPlugin: $selectedPlugin,
                selectedDynamicModule: $selectedDynamicModule,
                pluginOrder: pluginOrder,
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
                } else if let moduleId = selectedDynamicModule,
                          let descriptor = DynamicModuleRegistry.shared.modules[moduleId] {
                    descriptor.viewBuilder()
                        .id(moduleId)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                } else {
                    ToolkitDesktopGrid(
                        selectedPlugin: $selectedPlugin,
                        selectedDynamicModule: $selectedDynamicModule,
                        pluginOrder: $pluginOrder
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: selectedPlugin)
            .animation(.easeInOut(duration: 0.3), value: selectedDynamicModule)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                menuBarAppeared = true
            }
        }
        .onChange(of: selectedPlugin) { _, newValue in
            appState.isInToolkitModule = newValue != nil || selectedDynamicModule != nil
            if newValue != nil { selectedDynamicModule = nil }
        }
        .onChange(of: selectedDynamicModule) { _, newValue in
            appState.isInToolkitModule = selectedPlugin != nil || newValue != nil
            if newValue != nil { selectedPlugin = nil }
        }
        .onChange(of: appState.toolkitHomeSignal) {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedPlugin = nil
                selectedDynamicModule = nil
            }
        }
    }

    // MARK: - Tool Content

    /// Returns the content view for each static tool.
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
            CalendarPluginView()
        case .health:
            HealthView()
        case .bobo:
            BoboView()
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
    @Binding var selectedDynamicModule: String?
    var pluginOrder: [ToolkitPlugin]
    var namespace: Namespace.ID
    var appeared: Bool

    /// Whether nothing is selected (home state).
    private var isHome: Bool {
        selectedPlugin == nil && selectedDynamicModule == nil
    }

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
                        ForEach(pluginOrder) { plugin in
                            menuItem(for: plugin)
                        }
                        // Dynamic module menu items
                        ForEach(DynamicModuleRegistry.shared.orderedModules) { descriptor in
                            dynamicMenuItem(for: descriptor)
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
                selectedDynamicModule = nil
            }
        } label: {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    isHome
                        ? Color.hubPrimary
                        : AdaptiveColors.textSecondary(for: colorScheme)
                )
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isHome
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

    // MARK: - Menu Item (Static Plugin)

    private func menuItem(for plugin: ToolkitPlugin) -> some View {
        let isSelected = selectedPlugin == plugin

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedPlugin = plugin
            }
        } label: {
            HStack(spacing: 6) {
                if plugin == .bobo {
                    BoAvatar(size: 18)
                } else {
                    Image(systemName: plugin.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            isSelected ? plugin.iconColor : AdaptiveColors.textSecondary(for: colorScheme)
                        )
                }

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

    // MARK: - Menu Item (Dynamic Module)

    private func dynamicMenuItem(for descriptor: DynamicModuleDescriptor) -> some View {
        let isSelected = selectedDynamicModule == descriptor.toolkitId

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedDynamicModule = descriptor.toolkitId
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: descriptor.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        isSelected ? descriptor.iconColor : AdaptiveColors.textSecondary(for: colorScheme)
                    )

                Text(descriptor.shortName)
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
                            .fill(descriptor.iconColor.opacity(0.12))
                            .matchedGeometryEffect(id: "menuHighlight", in: namespace)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.toolkitMenuItem(descriptor.toolkitId))
    }
}

// MARK: - Desktop Grid

/// The "desktop" view showing all toolkit plugins in a 2-column card grid.
/// Supports long-press drag-to-reorder like the iPhone home screen.
struct ToolkitDesktopGrid: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedPlugin: ToolkitPlugin?
    @Binding var selectedDynamicModule: String?
    @Binding var pluginOrder: [ToolkitPlugin]

    /// Whether the grid is in reorder (jiggle) mode.
    @State private var isReordering = false

    /// The plugin currently being dragged.
    @State private var draggingPlugin: ToolkitPlugin?

    /// Drag position in the grid coordinate space.
    @State private var dragPosition: CGPoint = .zero

    /// Card frames for hit-testing during drag.
    @State private var cardFrames: [ToolkitPlugin: CGRect] = [:]

    /// Timer used to detect long-press without lifting the finger.
    @State private var longPressTimer: Timer?

    /// Plugin being pressed (before long-press threshold).
    @State private var pressingPlugin: ToolkitPlugin?

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

                // Plugin grid (static + dynamic)
                LazyVGrid(columns: columns, spacing: HubLayout.itemSpacing) {
                    ForEach(pluginOrder) { plugin in
                        cardView(for: plugin)
                            .accessibilityIdentifier(AccessibilityID.toolkitCard(plugin.rawValue))
                    }
                    // Dynamic module cards
                    ForEach(DynamicModuleRegistry.shared.orderedModules) { descriptor in
                        dynamicCardView(for: descriptor)
                            .accessibilityIdentifier(AccessibilityID.toolkitCard(descriptor.toolkitId))
                    }
                }
                .coordinateSpace(name: "desktopGrid")
                .onPreferenceChange(CardFramePreference.self) { frames in
                    cardFrames = frames
                }
                // Floating card that follows the finger during drag
                .overlay {
                    if let plugin = draggingPlugin, let frame = cardFrames[plugin] {
                        ToolkitPluginCard(
                            plugin: plugin,
                            isJiggling: false,
                            isDragging: true
                        )
                        .frame(width: frame.width, height: frame.height)
                        .position(dragPosition)
                        .allowsHitTesting(false)
                        .transition(.identity)
                    }
                }

                // "Done" button when in reorder mode
                if isReordering {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isReordering = false
                            draggingPlugin = nil
                        }
                    } label: {
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(Color.hubPrimary)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .accessibilityIdentifier(AccessibilityID.toolkitDesktopGrid)
    }

    // MARK: - Card View

    @ViewBuilder
    private func cardView(for plugin: ToolkitPlugin) -> some View {
        let isDragging = draggingPlugin == plugin

        ToolkitPluginCard(
            plugin: plugin,
            isJiggling: isReordering,
            isDragging: isDragging
        )
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: CardFramePreference.self,
                        value: [plugin: geo.frame(in: .named("desktopGrid"))]
                    )
            }
        )
        .opacity(isDragging ? 0.0 : 1.0)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("desktopGrid"))
                .onChanged { drag in
                    if draggingPlugin == plugin {
                        // Already dragging — update position
                        dragPosition = drag.location
                        checkSwap(for: plugin, at: drag.location)
                    } else if draggingPlugin == nil {
                        if pressingPlugin != plugin {
                            // Finger just touched down — start timer
                            pressingPlugin = plugin
                            longPressTimer?.invalidate()
                            longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { _ in
                                DispatchQueue.main.async {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isReordering = true
                                    }
                                    draggingPlugin = plugin
                                    dragPosition = drag.location
                                }
                            }
                        }
                        // If finger moves more than 10pt before timer fires, cancel (it's a scroll)
                        let moved = sqrt(pow(drag.translation.width, 2) + pow(drag.translation.height, 2))
                        if moved > 10 {
                            longPressTimer?.invalidate()
                            longPressTimer = nil
                            pressingPlugin = nil
                        }
                    }
                }
                .onEnded { drag in
                    longPressTimer?.invalidate()
                    longPressTimer = nil

                    if draggingPlugin == plugin {
                        // Was dragging — drop it
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            draggingPlugin = nil
                        }
                    } else if pressingPlugin == plugin {
                        // Short tap (timer didn't fire) — treat as tap
                        let moved = sqrt(pow(drag.translation.width, 2) + pow(drag.translation.height, 2))
                        if moved < 10 {
                            if isReordering {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isReordering = false
                                    draggingPlugin = nil
                                }
                            } else {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedPlugin = plugin
                                }
                            }
                        }
                    }
                    pressingPlugin = nil
                }
        )
    }

    // MARK: - Dynamic Module Card View

    private func dynamicCardView(for descriptor: DynamicModuleDescriptor) -> some View {
        DynamicModuleCard(descriptor: descriptor)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedDynamicModule = descriptor.toolkitId
                }
            }
    }

    /// Check if the dragged card should swap with another card.
    private func checkSwap(for plugin: ToolkitPlugin, at location: CGPoint) {
        guard let sourceIndex = pluginOrder.firstIndex(of: plugin) else { return }

        for (target, frame) in cardFrames {
            guard target != plugin,
                  frame.contains(location),
                  let targetIndex = pluginOrder.firstIndex(of: target) else { continue }

            let lightFeedback = UIImpactFeedbackGenerator(style: .light)
            lightFeedback.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                pluginOrder.swapAt(sourceIndex, targetIndex)
            }
            ToolkitPlugin.saveOrder(pluginOrder)
            break
        }
    }
}

/// Preference key for collecting card frames during layout.
private struct CardFramePreference: PreferenceKey {
    static var defaultValue: [ToolkitPlugin: CGRect] = [:]
    static func reduce(value: inout [ToolkitPlugin: CGRect], nextValue: () -> [ToolkitPlugin: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Plugin Card

/// A single plugin card in the toolkit desktop grid.
private struct ToolkitPluginCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let plugin: ToolkitPlugin
    var isJiggling: Bool = false
    var isDragging: Bool = false

    /// Per-card random jiggle seed so they don't all move in sync.
    @State private var jiggleSeed: Double = Double.random(in: 0...1)

    var body: some View {
        VStack(spacing: 10) {
            // Icon with tinted background circle (BoBo uses its cat avatar)
            if plugin == .bobo {
                BoAvatar(size: 48)
            } else {
                ZStack {
                    Circle()
                        .fill(plugin.iconColor.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: plugin.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(plugin.iconColor)
                }
            }

            VStack(spacing: 3) {
                Text(plugin.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(1)

                Text(plugin.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(AdaptiveColors.surface(for: colorScheme))
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(isDragging ? 0.5 : 0.3)
                        : Color.black.opacity(isDragging ? 0.12 : 0.06),
                    radius: isDragging ? 12 : 8,
                    x: 0,
                    y: isDragging ? 4 : 2
                )
        )
        .scaleEffect(isDragging ? 1.08 : 1.0)
        .rotationEffect(
            isJiggling && !isDragging
                ? .degrees(1.5 * sin(jiggleSeed * .pi * 2))
                : .zero
        )
        .animation(
            isJiggling && !isDragging
                ? .easeInOut(duration: 0.12 + jiggleSeed * 0.06)
                    .repeatForever(autoreverses: true)
                : .spring(response: 0.3, dampingFraction: 0.7),
            value: isJiggling
        )
        .onChange(of: isJiggling) { _, jiggling in
            if jiggling {
                // Re-randomize so the animation restarts with a fresh phase
                jiggleSeed = Double.random(in: 0...1)
            }
        }
    }
}

// MARK: - Dynamic Module Card

/// A card for a dynamically generated module, matching the visual style of ToolkitPluginCard.
private struct DynamicModuleCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let descriptor: DynamicModuleDescriptor

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(descriptor.iconColor.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: descriptor.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(descriptor.iconColor)
            }

            VStack(spacing: 3) {
                Text(descriptor.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(1)

                Text(descriptor.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
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
    case bobo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bookFactory: return L10n.toolkitBookFactory
        case .fluent: return L10n.toolkitFluent
        case .parking: return L10n.toolkitParking
        case .calendar: return L10n.toolkitCalendar
        case .health: return L10n.toolkitHealth
        case .bobo: return L10n.toolkitBobo
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
        case .bobo: return "BOBO"
        }
    }

    var subtitle: String {
        switch self {
        case .bookFactory: return L10n.toolkitBookFactoryDesc
        case .fluent: return L10n.toolkitFluentDesc
        case .parking: return L10n.toolkitParkingDesc
        case .calendar: return L10n.toolkitCalendarDesc
        case .health: return L10n.toolkitHealthDesc
        case .bobo: return L10n.toolkitBoboDesc
        }
    }

    var icon: String {
        switch self {
        case .bookFactory: return "book.fill"
        case .fluent: return "textformat.abc"
        case .parking: return "car.fill"
        case .calendar: return "calendar"
        case .health: return "heart.fill"
        case .bobo: return "waveform.path.ecg"
        }
    }

    var iconColor: Color {
        switch self {
        case .bookFactory: return .hubPrimary
        case .fluent: return .hubPrimaryLight
        case .parking: return .hubAccentGreen
        case .calendar: return .hubAccentYellow
        case .health: return .hubAccentRed
        case .bobo: return .hubPrimaryLight
        }
    }

    // MARK: - Order Persistence

    private static let orderKey = "ryanhub_toolkit_plugin_order"

    /// Load persisted plugin order, falling back to default CaseIterable order.
    static func loadOrder() -> [ToolkitPlugin] {
        guard let saved = UserDefaults.standard.stringArray(forKey: orderKey) else {
            return Array(allCases)
        }
        let mapped = saved.compactMap { ToolkitPlugin(rawValue: $0) }
        // Ensure all plugins are present (in case new ones were added)
        let missing = allCases.filter { !mapped.contains($0) }
        return mapped + missing
    }

    /// Save the current plugin order to UserDefaults.
    static func saveOrder(_ order: [ToolkitPlugin]) {
        UserDefaults.standard.set(order.map(\.rawValue), forKey: orderKey)
    }
}

// MARK: - Preview

#Preview {
    ToolkitHomeView()
}
