import SwiftUI
import os.log

private let viewLog = Logger(subsystem: "com.zwang.ryanhub", category: "TerminalView")

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
                    colorScheme: colorScheme,
                    onSizeChange: { cols, rows in
                        viewModel.ssh.resizeTerminal(cols: cols, rows: rows)
                    }
                )
                .ignoresSafeArea(.keyboard)
            } else {
                connectPrompt
            }

        }
        .background(AdaptiveColors.background(for: colorScheme))
        .overlay {
            if viewModel.showSessionPicker {
                sessionPickerOverlay
            }
        }
        .onChange(of: viewModel.ssh.isConnected) { _, isConnected in
            debugLog("onChange isConnected: \(isConnected)")
            if isConnected {
                // autoEnterTmux uses onShellReady callback — no blind delay needed
                viewModel.autoEnterTmux()
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
                Circle()
                    .fill(viewModel.ssh.isConnected ? Color.hubAccentGreen : Color.hubAccentRed)
                    .frame(width: 7, height: 7)

                if let session = viewModel.currentTmuxSession {
                    Text(session)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .lineLimit(1)
                } else if viewModel.ssh.isConnected {
                    Text("shell")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                } else {
                    Text("disconnected")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.7))
                }

                Spacer()

                if viewModel.ssh.isConnected {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .rotationEffect(.degrees(viewModel.showSessionPicker ? 180 : 0))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AdaptiveColors.surface(for: colorScheme))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.terminalSessionBar)
    }

    // MARK: - Connect Prompt

    @ViewBuilder
    private var connectPrompt: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "terminal.fill")
                .font(.system(size: 48))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5))

            if !viewModel.isConfigured {
                VStack(spacing: 8) {
                    Text("SSH Not Configured")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Text("Set host and username in Settings > Terminal")
                        .font(.system(size: 14))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            } else {
                VStack(spacing: 12) {
                    Text("\(viewModel.sshUsername)@\(viewModel.sshHost)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    if case .connecting = viewModel.ssh.state {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(AdaptiveColors.textSecondary(for: colorScheme))
                                .controlSize(.small)
                            Text("Connecting...")
                                .font(.system(size: 14))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
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
        .accessibilityIdentifier(AccessibilityID.terminalConnectButton)
    }

    // MARK: - Session Picker Overlay

    @ViewBuilder
    private var sessionPickerOverlay: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                if viewModel.isLoadingSessions {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(AdaptiveColors.textSecondary(for: colorScheme))
                            .controlSize(.small)
                        Text("Loading sessions...")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    .padding(.vertical, 12)
                } else if viewModel.tmuxSessions.isEmpty {
                    Text("No tmux sessions")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
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

                Divider().overlay(AdaptiveColors.border(for: colorScheme))

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
                .accessibilityIdentifier(AccessibilityID.terminalNewSession)
            }
            .background(AdaptiveColors.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            .padding(.horizontal, 8)
            .padding(.top, 44)
            .accessibilityIdentifier(AccessibilityID.terminalSessionPicker)

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

        HStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    viewModel.showSessionPicker = false
                }
                viewModel.attachTmuxSession(session.id)
            } label: {
                HStack(spacing: 8) {
                    Text(session.displayName)
                        .font(.system(size: 13, weight: isActive ? .bold : .regular, design: .monospaced))
                        .foregroundStyle(isActive ? Color.hubPrimary : AdaptiveColors.textPrimary(for: colorScheme))
                        .lineLimit(1)

                    Spacer()

                    if session.attached {
                        Text("attached")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.6))
                    }
                }
                .padding(.leading, 14)
                .padding(.vertical, 11)
            }
            .buttonStyle(.plain)

            // Kill session
            Button {
                viewModel.killTmuxSession(session.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
        }
        .background(isActive ? Color.hubPrimary.opacity(0.12) : Color.clear)
    }

}
