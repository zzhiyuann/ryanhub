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

            // Custom tab bar
            HStack(spacing: 0) {
                ForEach(MainTab.allCases, id: \.rawValue) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: selectedTab == tab ? .bold : .medium))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(selectedTab == tab ? Color.hubPrimary : AdaptiveColors.textSecondary(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tab_\(tab.rawValue)")
                }
            }
            .background(
                AdaptiveColors.surface(for: colorScheme)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .ignoresSafeArea(.keyboard)
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


// MARK: - Preview

#Preview {
    ContentView()
        .environment(AppState())
}
