import SwiftUI

/// Main chat screen — the primary interaction surface for Ryan Hub.
struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = ChatViewModel()
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Connection status bar
                connectionStatusBar

                // Messages area
                messagesArea

                // Input bar
                ChatInputBar(text: $viewModel.inputText, isConnected: viewModel.isConnected) {
                    viewModel.sendMessage()
                    scrollToBottom()
                }
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationTitle(L10n.tabChat)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            viewModel.clearHistory()
                        } label: {
                            Label("Clear History", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
            }
            .task {
                // Connect once when the view first appears.
                // Do NOT disconnect on disappear — the connection should persist
                // across tab switches and navigation.
                if !viewModel.isConnected {
                    viewModel.connect(to: appState.serverURL)
                }
            }
            .onChange(of: appState.serverURL) { _, newURL in
                viewModel.disconnect()
                viewModel.connect(to: newURL)
            }
            .onChange(of: viewModel.messages.count) {
                scrollToBottom()
            }
        }
    }

    // MARK: - Connection Status Bar

    private var statusColor: Color {
        switch viewModel.connectionState {
        case .connected: return Color.hubAccentGreen
        case .connecting, .reconnecting: return Color.hubAccentYellow
        case .disconnected, .failed: return Color.hubAccentRed
        }
    }

    private var statusText: String {
        switch viewModel.connectionState {
        case .connected: return L10n.chatConnected
        case .connecting: return "Connecting..."
        case .reconnecting(let attempt): return "Reconnecting (\(attempt)/5)..."
        case .disconnected: return L10n.chatDisconnected
        case .failed(let reason):
            if reason.contains("Max reconnect") {
                return "Cannot reach Dispatcher"
            }
            return L10n.chatDisconnected
        }
    }

    @ViewBuilder
    private var connectionStatusBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Spacer()

            if case .failed = viewModel.connectionState {
                Button("Retry") {
                    viewModel.retry()
                }
                .font(.hubCaption)
                .foregroundStyle(Color.hubPrimary)
            }
        }
        .padding(.horizontal, HubLayout.standardPadding)
        .padding(.vertical, 6)
        .background(AdaptiveColors.surface(for: colorScheme).opacity(0.8))
    }

    // MARK: - Messages Area

    @ViewBuilder
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: HubLayout.itemSpacing) {
                    if viewModel.messages.isEmpty {
                        emptyState
                            .padding(.top, 80)
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }

                    if viewModel.isTyping {
                        TypingIndicator()
                            .id("typing-indicator")
                    }

                    // Invisible anchor for scrolling
                    Color.clear
                        .frame(height: 1)
                        .id("bottom-anchor")
                }
                .padding(.horizontal, HubLayout.standardPadding)
                .padding(.vertical, HubLayout.itemSpacing)
            }
            .onAppear {
                scrollProxy = proxy
                scrollToBottom()
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🐱")
                .font(.system(size: 64))

            Text(L10n.chatWelcomeTitle)
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text(L10n.chatWelcomeMessage)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func scrollToBottom() {
        withAnimation(.easeOut(duration: 0.2)) {
            scrollProxy?.scrollTo("bottom-anchor", anchor: .bottom)
        }
    }
}

#Preview {
    ChatView()
        .environment(AppState())
}
