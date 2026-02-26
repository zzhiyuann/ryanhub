import SwiftUI

// MARK: - Tab Definition

/// The three main tabs in the app.
enum MainTab: String, CaseIterable {
    case chat
    case toolkit
    case settings

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .toolkit: return "square.grid.2x2.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var label: String {
        switch self {
        case .chat: return L10n.tabChat
        case .toolkit: return L10n.tabToolkit
        case .settings: return L10n.tabSettings
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: MainTab = .chat
    /// ChatViewModel is owned here so it survives tab switches.
    @State private var chatViewModel = ChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Content area — fills all available space above the tab bar
            ZStack {
                switch selectedTab {
                case .chat:
                    ChatView(viewModel: chatViewModel)
                case .toolkit:
                    ToolkitHomeView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Separator line above tab bar
            AdaptiveColors.border(for: colorScheme)
                .frame(height: 0.5)

            // Custom tab bar — flush against bottom edge
            CustomTabBar(
                selectedTab: $selectedTab,
                isCompact: appState.isInToolkitModule
            )
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }
}

// MARK: - Custom Tab Bar

/// A custom tab bar that sits flush against the bottom edge of the screen.
/// Supports a compact mode (icon-only, shorter height) when inside a toolkit module.
struct CustomTabBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: MainTab
    var isCompact: Bool

    /// Full tab bar height (icon + label + padding).
    private let fullHeight: CGFloat = 50
    /// Compact tab bar height (icon only + reduced padding).
    private let compactHeight: CGFloat = 36

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.rawValue) { tab in
                tabButton(for: tab)
            }
        }
        .frame(height: isCompact ? compactHeight : fullHeight)
        .padding(.bottom, safeAreaBottomInset)
        .background(
            AdaptiveColors.surface(for: colorScheme)
                .ignoresSafeArea(edges: .bottom)
        )
        .animation(.easeInOut(duration: 0.25), value: isCompact)
    }

    // MARK: - Tab Button

    private func tabButton(for tab: MainTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: isCompact ? 0 : 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: isCompact ? 18 : 20, weight: .medium))
                    .symbolRenderingMode(.monochrome)

                if !isCompact {
                    Text(tab.label)
                        .font(.hubCaption)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .foregroundStyle(isSelected ? Color.hubPrimary : AdaptiveColors.textSecondary(for: colorScheme))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: selectedTab)
    }

    // MARK: - Safe Area

    /// Returns the bottom safe area inset for devices with a home indicator (e.g. iPhone X+).
    /// Falls back to 0 for devices with a physical home button.
    private var safeAreaBottomInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(AppState())
}
