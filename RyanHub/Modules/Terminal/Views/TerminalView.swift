import SwiftUI

/// Main terminal screen with SSH connection, tmux session dropdown, and shortcut keyboard.
struct SSHTerminalView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: TerminalViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Session dropdown bar
            sessionBar

            // Terminal content
            if viewModel.ssh.isConnected {
                SwiftTermView(
                    ssh: viewModel.ssh,
                    onSizeChange: { cols, rows in
                        viewModel.ssh.resizeTerminal(cols: cols, rows: rows)
                    }
                )
                .ignoresSafeArea(.keyboard)
            } else {
                connectPrompt
            }

            // Floating shortcut keyboard (only when connected)
            if viewModel.ssh.isConnected {
                shortcutKeyboard
            }
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.06))
        .overlay {
            // Session picker dropdown
            if viewModel.showSessionPicker {
                sessionPickerOverlay
            }
        }
    }

    // MARK: - Session Bar

    @ViewBuilder
    private var sessionBar: some View {
        Button {
            if viewModel.ssh.isConnected {
                viewModel.refreshTmuxSessions()
                withAnimation(.easeOut(duration: 0.2)) {
                    viewModel.showSessionPicker.toggle()
                }
            }
        } label: {
            HStack(spacing: 8) {
                // Connection indicator
                Circle()
                    .fill(viewModel.ssh.isConnected ? Color.hubAccentGreen : Color.hubAccentRed)
                    .frame(width: 7, height: 7)

                if let session = viewModel.currentTmuxSession {
                    Text(session)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                } else if viewModel.ssh.isConnected {
                    Text("shell")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Text("disconnected")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                if viewModel.ssh.isConnected {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .rotationEffect(.degrees(viewModel.showSessionPicker ? 180 : 0))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Connect Prompt

    @ViewBuilder
    private var connectPrompt: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "terminal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))

            if !viewModel.isConfigured {
                VStack(spacing: 8) {
                    Text("SSH Not Configured")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))

                    Text("Set host and username in Settings > Terminal")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                }
            } else {
                VStack(spacing: 12) {
                    Text("\(viewModel.sshUsername)@\(viewModel.sshHost)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))

                    if case .connecting = viewModel.ssh.state {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white.opacity(0.6))
                                .controlSize(.small)
                            Text("Connecting...")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    } else if case .failed(let reason) = viewModel.ssh.state {
                        Text(reason)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.hubAccentRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        connectButton
                    } else {
                        connectButton
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.hubAccentRed)
                    .padding(.horizontal, 32)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var connectButton: some View {
        Button {
            viewModel.connect()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13))
                Text("Connect")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.hubPrimary)
            )
        }
    }

    // MARK: - Session Picker Overlay

    @ViewBuilder
    private var sessionPickerOverlay: some View {
        VStack(spacing: 0) {
            // Dropdown positioned below session bar
            VStack(spacing: 0) {
                if viewModel.isLoadingSessions {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white.opacity(0.6))
                            .controlSize(.small)
                        Text("Loading sessions...")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.vertical, 12)
                } else if viewModel.tmuxSessions.isEmpty {
                    Text("No tmux sessions")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.vertical, 12)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.tmuxSessions) { session in
                                sessionRow(session)
                            }
                        }
                    }
                    .frame(maxHeight: 240)
                }

                Divider().overlay(Color.white.opacity(0.1))

                // New session button
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        viewModel.showSessionPicker = false
                    }
                    viewModel.newClaudeSession()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("New Claude Session")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(Color.hubPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
            }
            .background(Color(red: 0.1, green: 0.1, blue: 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
            .padding(.horizontal, 8)
            .padding(.top, 44) // Below session bar

            Spacer()
        }
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        viewModel.showSessionPicker = false
                    }
                }
        )
        .transition(.opacity)
    }

    @ViewBuilder
    private func sessionRow(_ session: TmuxSession) -> some View {
        let isActive = session.id == viewModel.currentTmuxSession

        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                viewModel.showSessionPicker = false
            }
            viewModel.attachTmuxSession(session.id)
        } label: {
            HStack(spacing: 8) {
                Text(session.displayName)
                    .font(.system(size: 13, weight: isActive ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(isActive ? Color.hubPrimary : .white.opacity(0.8))
                    .lineLimit(1)

                Spacer()

                if session.attached {
                    Text("attached")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(isActive ? Color.hubPrimary.opacity(0.12) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shortcut Keyboard

    @ViewBuilder
    private var shortcutKeyboard: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                shortcutKey("C-c", Color.hubAccentRed.opacity(0.8)) { viewModel.sendCtrlC() }
                shortcutKey("Tab", .white.opacity(0.5)) { viewModel.sendTab() }
                shortcutKey("\u{2191}", .white.opacity(0.5)) { viewModel.sendArrowUp() }
                shortcutKey("\u{2193}", .white.opacity(0.5)) { viewModel.sendArrowDown() }
                shortcutKey("Esc", .white.opacity(0.5)) { viewModel.sendEscape() }
                shortcutKey("C-z", .white.opacity(0.5)) { viewModel.sendCtrlZ() }
                shortcutKey("C-d", .white.opacity(0.5)) { viewModel.sendCtrlD() }
                shortcutKey("C-l", .white.opacity(0.5)) { viewModel.sendCtrlL() }
                shortcutKey("y", Color.hubAccentGreen.opacity(0.7)) { viewModel.sendY() }
                shortcutKey("n", Color.hubAccentRed.opacity(0.6)) { viewModel.sendN() }
                shortcutKey("/", .white.opacity(0.5)) { viewModel.sendSlash() }
                shortcutKey("q", .white.opacity(0.5)) { viewModel.sendQ() }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .background(Color.white.opacity(0.04))
    }

    @ViewBuilder
    private func shortcutKey(_ label: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }
}
