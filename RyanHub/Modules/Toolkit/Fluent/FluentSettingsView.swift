import SwiftUI

// MARK: - Fluent Settings View

/// Settings sheet for the Fluent module.
/// Configures TTS voice, speed, daily goal, Chinese display, and API key.
struct FluentSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let viewModel: FluentViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HubLayout.sectionSpacing) {
                    // TTS Settings
                    ttsSection

                    // Study Settings
                    studySection

                    // Display Settings
                    displaySection

                    // API Settings
                    apiSection

                    // Data Info
                    dataInfoSection
                }
                .padding(.horizontal, HubLayout.standardPadding)
                .padding(.vertical, HubLayout.sectionSpacing)
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationTitle("Fluent Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        viewModel.saveSettings()
                        dismiss()
                    }
                    .foregroundStyle(Color.hubPrimary)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - TTS Section

    private var ttsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Text-to-Speech")

            HubCard {
                VStack(alignment: .leading, spacing: 16) {
                    // Voice selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Voice")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        Text("Using system voice (AVSpeechSynthesizer)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                        .background(AdaptiveColors.border(for: colorScheme))

                    // Speed slider
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speed")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                            Spacer()

                            Text(String(format: "%.1fx", viewModel.settings.ttsSpeed))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.hubPrimary)
                        }

                        Slider(
                            value: Binding(
                                get: { viewModel.settings.ttsSpeed },
                                set: { viewModel.settings.ttsSpeed = $0 }
                            ),
                            in: 0.5...2.0,
                            step: 0.1
                        )
                        .tint(Color.hubPrimary)

                        HStack {
                            Text("Slow")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            Spacer()
                            Text("Fast")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Study Section

    private var studySection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Study")

            HubCard {
                VStack(alignment: .leading, spacing: 16) {
                    // Daily goal
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Daily Goal")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                            Spacer()

                            Text("\(viewModel.settings.dailyGoal) cards")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.hubPrimary)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(viewModel.settings.dailyGoal) },
                                set: { viewModel.settings.dailyGoal = Int($0) }
                            ),
                            in: 5...100,
                            step: 5
                        )
                        .tint(Color.hubPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                        .background(AdaptiveColors.border(for: colorScheme))

                    // New cards per day
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("New Cards per Day")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                            Spacer()

                            Text("\(viewModel.settings.dailyNewCards)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.hubPrimary)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(viewModel.settings.dailyNewCards) },
                                set: { viewModel.settings.dailyNewCards = Int($0) }
                            ),
                            in: 1...50,
                            step: 1
                        )
                        .tint(Color.hubPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Display Section

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Display")

            HubCard {
                Toggle(isOn: Binding(
                    get: { viewModel.settings.showChinese },
                    set: { viewModel.settings.showChinese = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Chinese Definitions")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        Text("Display Chinese translations alongside English definitions")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
                .tint(Color.hubPrimary)
            }
        }
    }

    // MARK: - API Section

    private var apiSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "API (Optional)")

            HubCard {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OpenAI API Key")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        Text("For future premium TTS features. Currently using system voice.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    HubTextField(
                        placeholder: "sk-...",
                        text: Binding(
                            get: { viewModel.settings.openaiApiKey ?? "" },
                            set: { viewModel.settings.openaiApiKey = $0.isEmpty ? nil : $0 }
                        ),
                        isSecure: true
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Data Info

    private var dataInfoSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Data")

            HubCard {
                VStack(alignment: .leading, spacing: 12) {
                    infoRow(label: "Vocabulary Items", value: "\(viewModel.allVocabulary.count)")
                    Divider().background(AdaptiveColors.border(for: colorScheme))
                    infoRow(label: "Total Reviews", value: "\(viewModel.progress.totalCardsReviewed)")
                    Divider().background(AdaptiveColors.border(for: colorScheme))
                    infoRow(label: "Current Streak", value: "\(viewModel.progress.currentStreak) days")
                    Divider().background(AdaptiveColors.border(for: colorScheme))
                    infoRow(label: "Longest Streak", value: "\(viewModel.progress.longestStreak) days")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
        }
    }
}
