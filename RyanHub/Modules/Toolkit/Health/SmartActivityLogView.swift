import SwiftUI

// MARK: - Smart Activity Log View

/// AI-powered activity logging — type what you did in natural language.
/// Claude analyzes the activity and estimates calories burned automatically.
struct SmartActivityLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let viewModel: HealthViewModel
    var initialText: String = ""

    @State private var activityDescription = ""
    @State private var analysisResult: ActivityAnalysisResult?
    @State private var analysisService = FoodAnalysisService()
    @State private var showManualLog = false
    @State private var date = Date()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HubLayout.sectionSpacing) {
                    inputSection
                    if analysisService.isAnalyzing {
                        analyzingIndicator
                    }
                    if let error = analysisService.analysisError {
                        errorBanner(error)
                    }
                    if let result = analysisResult {
                        analysisResultView(result)
                    }

                    manualFallbackSection
                }
                .padding(HubLayout.standardPadding)
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.hubPrimary)
                }
            }
            .onAppear {
                analysisService.updateBaseURL(appState.foodAnalysisURL)
                if !initialText.isEmpty {
                    activityDescription = initialText
                    Task { await analyzeCurrentInput() }
                } else {
                    isInputFocused = true
                }
            }
            .sheet(isPresented: $showManualLog) {
                ActivityLogSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "What did you do?")

            VStack(spacing: 0) {
                TextField("e.g., 'Walked 30 min to campus' or 'Gym for an hour'",
                          text: $activityDescription, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(1...3)
                    .focused($isInputFocused)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                    .onSubmit {
                        guard canAnalyze else { return }
                        Task { await analyzeCurrentInput() }
                    }
                    .submitLabel(.send)

                // Action bar
                HStack(spacing: 12) {
                    Spacer()

                    // Date picker (compact)
                    DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(.hubPrimary)
                        .scaleEffect(0.85)

                    // Analyze button
                    Button {
                        Task { await analyzeCurrentInput() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                            Text("Analyze")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                canAnalyze
                                    ? Color.hubAccentGreen
                                    : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3)
                            )
                        )
                    }
                    .disabled(!canAnalyze || analysisService.isAnalyzing)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                    .fill(AdaptiveColors.surface(for: colorScheme))
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.3)
                            : Color.black.opacity(0.06),
                        radius: 8, x: 0, y: 2
                    )
            )

            Text("Describe your activity in any language. AI will estimate calories burned.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
    }

    private var canAnalyze: Bool {
        !activityDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Manual Fallback

    private var manualFallbackSection: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 4)

            Button {
                showManualLog = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .medium))
                    Text("Log manually instead")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Color.hubPrimary)
            }
        }
    }

    // MARK: - Analyzing Indicator

    private var analyzingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Color.hubAccentGreen)

            VStack(alignment: .leading, spacing: 2) {
                Text("Analyzing your activity...")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Text("AI is estimating calories burned")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            Spacer()
        }
        .padding(HubLayout.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(Color.hubAccentGreen.opacity(0.08))
        )
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.hubAccentYellow)
            Text(error)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.hubAccentYellow.opacity(0.1))
        )
    }

    // MARK: - Analysis Result

    private func analysisResultView(_ result: ActivityAnalysisResult) -> some View {
        VStack(spacing: HubLayout.itemSpacing) {
            // Summary header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Analysis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.hubAccentGreen)
                    Text(result.summary)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.hubAccentGreen)
            }
            .padding(HubLayout.cardInnerPadding)
            .background(
                RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                    .fill(Color.hubAccentGreen.opacity(0.06))
            )

            // Activity type + calories burned
            HStack(spacing: 16) {
                // Activity type card
                VStack(spacing: 8) {
                    Image(systemName: ActivityParser.icon(for: result.type))
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color.hubAccentGreen)

                    Text(result.type)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.hubAccentGreen.opacity(0.08))
                )

                // Calories burned card
                VStack(spacing: 4) {
                    Text("\(result.caloriesBurned)")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.hubAccentYellow)
                    Text("kcal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.hubAccentYellow.opacity(0.7))
                    Text("Burned")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.hubAccentYellow.opacity(0.08))
                )
            }

            // Save button
            HubButton("Save Activity", icon: "checkmark.circle.fill") {
                saveActivity(result)
            }
        }
    }

    // MARK: - Actions

    private func analyzeCurrentInput() async {
        isInputFocused = false
        analysisResult = await analysisService.analyzeActivity(activityDescription)
    }

    private func saveActivity(_ result: ActivityAnalysisResult) {
        viewModel.addActivityFromAnalysis(result, description: activityDescription, date: date)
        dismiss()
    }
}

#Preview {
    SmartActivityLogView(viewModel: HealthViewModel(), initialText: "")
}
