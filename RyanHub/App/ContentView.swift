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

/// Sub-mode within the Chat tab: Chat or Terminal.
enum ChatMode: String {
    case chat
    case terminal
}

// MARK: - Content View

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: MainTab = .chat
    @State private var chatMode: ChatMode = .chat
    /// ChatViewModel is owned here so it survives tab switches.
    @State private var chatViewModel = ChatViewModel()
    /// TerminalViewModel is owned here so it survives tab/mode switches.
    @State private var terminalViewModel = TerminalViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Content area — fills all available space above the tab bar
            ZStack {
                switch selectedTab {
                case .chat:
                    chatOrTerminalContent
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

    // MARK: - Chat / Terminal Content

    @ViewBuilder
    private var chatOrTerminalContent: some View {
        VStack(spacing: 0) {
            // Mode toggle bubble
            chatModeToggle

            // Content
            ZStack {
                if chatMode == .chat {
                    ChatView(viewModel: chatViewModel)
                        .transition(.opacity)
                } else {
                    SSHTerminalView(viewModel: terminalViewModel)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: chatMode)
        }
    }

    /// Connection status color for the chat icon.
    private var chatStatusColor: Color {
        switch chatViewModel.connectionState {
        case .connected: return Color.hubAccentGreen
        default: return Color.hubAccentRed
        }
    }

    /// Connection status color for the terminal icon.
    private var terminalStatusColor: Color {
        terminalViewModel.ssh.isConnected ? Color.hubAccentGreen : Color.hubAccentRed
    }

    @ViewBuilder
    private var chatModeToggle: some View {
        HStack(spacing: 0) {
            modeButton(icon: "bubble.left.and.bubble.right.fill", mode: .chat, statusColor: chatStatusColor)
            modeButton(icon: "terminal.fill", mode: .terminal, statusColor: terminalStatusColor)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
        )
        .padding(.horizontal, 100)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func modeButton(icon: String, mode: ChatMode, statusColor: Color) -> some View {
        let isSelected = chatMode == mode
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                chatMode = mode
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? statusColor : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? AdaptiveColors.surface(for: colorScheme) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(mode == .chat ? AccessibilityID.modeChatButton : AccessibilityID.modeTerminalButton)
    }
}

// MARK: - Custom Tab Bar

/// A custom tab bar that sits flush against the bottom edge of the screen.
/// Supports a compact mode (icon-only, shorter height) when inside a toolkit module.
struct CustomTabBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: MainTab
    var isCompact: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.rawValue) { tab in
                tabButton(for: tab)
            }
        }
        .frame(height: 32)
        .padding(.bottom, safeAreaBottomInset)
        .background(
            AdaptiveColors.surface(for: colorScheme)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Tab Button

    @ViewBuilder
    private func tabButton(for tab: MainTab) -> some View {
        let isSelected = selectedTab == tab
        Button {
            selectedTab = tab
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 17, weight: isSelected ? .bold : .medium))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isSelected ? Color.hubPrimary : AdaptiveColors.textSecondary(for: colorScheme))
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab_\(tab.rawValue)")
    }

    // MARK: - Safe Area

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
