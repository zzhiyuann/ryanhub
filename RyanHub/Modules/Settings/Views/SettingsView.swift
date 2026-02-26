import SwiftUI

/// Settings screen with server configuration, appearance, language, and about sections.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HubLayout.sectionSpacing) {
                    serverSection
                    terminalSection
                    appearanceSection
                    languageSection
                    aboutSection
                }
                .padding(HubLayout.standardPadding)
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationTitle(L10n.settingsTitle)
        }
        .onAppear {
            viewModel.loadFromAppState(appState)
        }
    }

    // MARK: - Server Section

    @ViewBuilder
    private var serverSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: L10n.settingsServer)

            HubCard {
                VStack(spacing: HubLayout.itemSpacing) {
                    // WebSocket URL input
                    TextField("ws://localhost:8765 or ws://192.168.1.x:8765", text: Bindable(appState).serverURL)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, HubLayout.standardPadding)
                        .frame(height: HubLayout.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: HubLayout.inputCornerRadius)
                                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: HubLayout.inputCornerRadius)
                                .stroke(
                                    viewModel.serverURLWarning != nil
                                        ? Color.hubAccentRed.opacity(0.5)
                                        : AdaptiveColors.border(for: colorScheme),
                                    lineWidth: 1
                                )
                        )
                        .onChange(of: appState.serverURL) { _, newValue in
                            viewModel.validateServerURL(newValue)
                        }

                    // URL validation warning
                    if let warning = viewModel.serverURLWarning {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text(warning)
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(Color.hubAccentYellow)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Preset buttons
                    HStack(spacing: 8) {
                        presetButton(title: "Localhost", icon: "desktopcomputer") {
                            appState.serverURL = AppState.defaultServerURL
                        }

                        presetButton(title: L10n.settingsResetToDefault, icon: "arrow.counterclockwise") {
                            appState.resetServerURLs()
                        }
                    }

                    HStack(spacing: HubLayout.itemSpacing) {
                        // Connection status
                        HStack(spacing: 6) {
                            Circle()
                                .fill(settingsStatusColor)
                                .frame(width: 8, height: 8)
                            Text(settingsStatusText)
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                .lineLimit(1)
                        }

                        Spacer()

                        // Test button
                        Button {
                            viewModel.testConnection(url: appState.serverURL)
                        } label: {
                            HStack(spacing: 6) {
                                if viewModel.isTesting {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: viewModel.testResultIcon ?? "bolt.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text(L10n.settingsTestConnection)
                                    .font(.hubCaption)
                            }
                            .foregroundStyle(Color.hubPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.hubPrimary.opacity(0.1))
                            )
                        }
                        .disabled(viewModel.isTesting)
                    }

                    // Show error detail if there is one
                    if let error = appState.connectionError, !appState.isConnected {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.hubAccentRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Preset Button

    @ViewBuilder
    private func presetButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Settings Status Helpers

    private var settingsStatusColor: Color {
        switch appState.connectionState {
        case .connected: return Color.hubAccentGreen
        case .connecting, .reconnecting: return Color.hubAccentYellow
        case .disconnected, .failed: return Color.hubAccentRed
        }
    }

    private var settingsStatusText: String {
        switch appState.connectionState {
        case .connected: return L10n.chatConnected
        case .connecting: return "Connecting..."
        case .reconnecting(let attempt): return "Reconnecting (\(attempt)/5)..."
        case .disconnected: return L10n.chatDisconnected
        case .failed(let reason): return "Failed: \(reason)"
        }
    }

    // MARK: - Terminal (SSH) Section

    @ViewBuilder
    private var terminalSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Terminal (SSH)")

            HubCard {
                VStack(spacing: HubLayout.itemSpacing) {
                    // Host
                    settingsInput(
                        placeholder: "100.89.67.80",
                        text: Binding(
                            get: { UserDefaults.standard.string(forKey: "ryanhub_ssh_host") ?? "100.89.67.80" },
                            set: { UserDefaults.standard.set($0, forKey: "ryanhub_ssh_host") }
                        ),
                        label: "Host"
                    )

                    // Username
                    settingsInput(
                        placeholder: "zwang",
                        text: Binding(
                            get: { UserDefaults.standard.string(forKey: "ryanhub_ssh_username") ?? "zwang" },
                            set: { UserDefaults.standard.set($0, forKey: "ryanhub_ssh_username") }
                        ),
                        label: "Username"
                    )

                    // Password
                    settingsInput(
                        placeholder: "SSH password",
                        text: Binding(
                            get: { UserDefaults.standard.string(forKey: "ryanhub_ssh_password") ?? "" },
                            set: { UserDefaults.standard.set($0, forKey: "ryanhub_ssh_password") }
                        ),
                        label: "Password",
                        isSecure: true
                    )

                    // Test SSH button
                    HStack(spacing: HubLayout.itemSpacing) {
                        if let error = viewModel.sshTestError {
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.hubAccentRed)
                                .lineLimit(2)
                        }

                        Spacer()

                        Button {
                            viewModel.testSSHConnection()
                        } label: {
                            HStack(spacing: 6) {
                                if viewModel.isTestingSSH {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: viewModel.sshTestResultIcon ?? "bolt.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text("Test SSH")
                                    .font(.hubCaption)
                            }
                            .foregroundStyle(Color.hubPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.hubPrimary.opacity(0.1))
                            )
                        }
                        .disabled(viewModel.isTestingSSH)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func settingsInput(placeholder: String, text: Binding<String>, label: String, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: HubLayout.inputCornerRadius)
                    .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HubLayout.inputCornerRadius)
                    .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 1)
            )
        }
    }

    // MARK: - Appearance Section

    @ViewBuilder
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: L10n.settingsAppearance)

            HubCard {
                HStack(spacing: 0) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                appState.appearanceMode = mode
                            }
                        } label: {
                            Text(mode.displayName)
                                .font(.hubCaption)
                                .foregroundStyle(
                                    appState.appearanceMode == mode
                                        ? .white
                                        : AdaptiveColors.textSecondary(for: colorScheme)
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            appState.appearanceMode == mode
                                                ? Color.hubPrimary
                                                : Color.clear
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Language Section

    @ViewBuilder
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: L10n.settingsLanguage)

            HubCard {
                HStack(spacing: 0) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                appState.language = lang
                            }
                        } label: {
                            Text(lang.displayName)
                                .font(.hubCaption)
                                .foregroundStyle(
                                    appState.language == lang
                                        ? .white
                                        : AdaptiveColors.textSecondary(for: colorScheme)
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            appState.language == lang
                                                ? Color.hubPrimary
                                                : Color.clear
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - About Section

    @ViewBuilder
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: L10n.settingsAbout)

            HubCard {
                VStack(spacing: HubLayout.itemSpacing) {
                    aboutRow(label: L10n.settingsVersion, value: viewModel.appVersion)
                    Divider().overlay(AdaptiveColors.border(for: colorScheme))
                    aboutRow(label: L10n.settingsBuild, value: viewModel.buildNumber)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            Spacer()
            Text(value)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
