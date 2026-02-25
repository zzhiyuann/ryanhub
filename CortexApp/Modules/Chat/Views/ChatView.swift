import SwiftUI

/// Main chat screen — the primary interaction surface for Cortex.
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
            .onAppear {
                viewModel.connect(to: appState.serverURL)
            }
            .onDisappear {
                viewModel.disconnect()
            }
            .onChange(of: viewModel.messages.count) {
                scrollToBottom()
            }
        }
    }

    // MARK: - Connection Status Bar

    @ViewBuilder
    private var connectionStatusBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isConnected ? Color.cortexAccentGreen : Color.cortexAccentRed)
                .frame(width: 8, height: 8)

            Text(viewModel.isConnected ? L10n.chatConnected : L10n.chatDisconnected)
                .font(.cortexCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Spacer()
        }
        .padding(.horizontal, CortexLayout.standardPadding)
        .padding(.vertical, 6)
        .background(AdaptiveColors.surface(for: colorScheme).opacity(0.8))
    }

    // MARK: - Messages Area

    @ViewBuilder
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: CortexLayout.itemSpacing) {
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
                .padding(.horizontal, CortexLayout.standardPadding)
                .padding(.vertical, CortexLayout.itemSpacing)
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
                .font(.cortexHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text(L10n.chatWelcomeMessage)
                .font(.cortexBody)
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
