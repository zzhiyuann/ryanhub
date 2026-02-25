import SwiftUI

/// Settings screen with server configuration, appearance, language, and about sections.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CortexLayout.sectionSpacing) {
                    serverSection
                    appearanceSection
                    languageSection
                    aboutSection
                }
                .padding(CortexLayout.standardPadding)
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
        VStack(alignment: .leading, spacing: CortexLayout.itemSpacing) {
            SectionHeader(title: L10n.settingsServer)

            CortexCard {
                VStack(spacing: CortexLayout.itemSpacing) {
                    CortexTextField(
                        placeholder: "ws://localhost:8765",
                        text: Bindable(appState).serverURL
                    )

                    HStack(spacing: CortexLayout.itemSpacing) {
                        // Connection status
                        HStack(spacing: 6) {
                            Circle()
                                .fill(appState.isConnected ? Color.cortexAccentGreen : Color.cortexAccentRed)
                                .frame(width: 8, height: 8)
                            Text(appState.isConnected ? L10n.chatConnected : L10n.chatDisconnected)
                                .font(.cortexCaption)
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
                                    .font(.cortexCaption)
                            }
                            .foregroundStyle(Color.cortexPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.cortexPrimary.opacity(0.1))
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
        VStack(alignment: .leading, spacing: CortexLayout.itemSpacing) {
            SectionHeader(title: L10n.settingsAppearance)

            CortexCard {
                HStack(spacing: 0) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                appState.appearanceMode = mode
                            }
                        } label: {
                            Text(mode.displayName)
                                .font(.cortexCaption)
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
                                                ? Color.cortexPrimary
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
        VStack(alignment: .leading, spacing: CortexLayout.itemSpacing) {
            SectionHeader(title: L10n.settingsLanguage)

            CortexCard {
                HStack(spacing: 0) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                appState.language = lang
                            }
                        } label: {
                            Text(lang.displayName)
                                .font(.cortexCaption)
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
                                                ? Color.cortexPrimary
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
        VStack(alignment: .leading, spacing: CortexLayout.itemSpacing) {
            SectionHeader(title: L10n.settingsAbout)

            CortexCard {
                VStack(spacing: CortexLayout.itemSpacing) {
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
                .font(.cortexBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            Spacer()
            Text(value)
                .font(.cortexBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
