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
                    HubTextField(
                        placeholder: "ws://localhost:8765",
                        text: Bindable(appState).serverURL
                    )

                    HStack(spacing: HubLayout.itemSpacing) {
                        // Connection status
                        HStack(spacing: 6) {
                            Circle()
                                .fill(appState.isConnected ? Color.hubAccentGreen : Color.hubAccentRed)
                                .frame(width: 8, height: 8)
                            Text(appState.isConnected ? L10n.chatConnected : L10n.chatDisconnected)
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
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
                }
                .frame(maxWidth: .infinity)
            }
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
