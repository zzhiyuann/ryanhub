import SwiftUI
import PhotosUI

// MARK: - Health View

/// Main health tracking view with tabs for weight, food, and activity.
/// Food and activity analysis happens inline — no sheet popups.
struct HealthView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = HealthViewModel()
    @State private var showWeightLog = false

    // Quick meal input
    @State private var quickMealText = ""
    @FocusState private var isQuickMealFocused: Bool

    // Quick activity input
    @State private var quickActivityText = ""
    @FocusState private var isQuickActivityFocused: Bool

    // Inline food analysis state
    @State private var foodAnalysisService = FoodAnalysisService()
    @State private var foodAnalysisResult: FoodAnalysisResult?
    @State private var isFoodAnalyzing = false
    @State private var foodAnalysisError: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showCamera = false
    @State private var foodAnalysisDate = Date()
    @State private var foodAnalysisDescription = ""

    // Inline activity analysis state
    @State private var activityAnalysisResult: ActivityAnalysisResult?
    @State private var isActivityAnalyzing = false
    @State private var activityAnalysisError: String?
    @State private var activityAnalysisDate = Date()
    @State private var activityAnalysisDescription = ""

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                tabSelector
                selectedTabContent
            }
            .padding(HubLayout.standardPadding)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AdaptiveColors.background(for: colorScheme))
        .sheet(isPresented: $showWeightLog) {
            WeightLogView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                selectedImage = image
                Task { await analyzeFoodInput() }
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task { await loadPhoto(newValue) }
        }
        .onAppear {
            foodAnalysisService.updateBaseURL(appState.foodAnalysisURL)
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(HealthTab.allCases) { tab in
                Button {
                    // Dismiss keyboard when switching tabs
                    isQuickMealFocused = false
                    isQuickActivityFocused = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .medium))
                        Text(tab.displayName)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(
                        viewModel.selectedTab == tab
                            ? .white
                            : AdaptiveColors.textSecondary(for: colorScheme)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(viewModel.selectedTab == tab
                                ? Color.hubPrimary
                                : Color.clear)
                    )
                }
                .accessibilityIdentifier(
                    tab == .weight ? AccessibilityID.healthTabWeight :
                    tab == .food ? AccessibilityID.healthTabFood :
                    AccessibilityID.healthTabActivity
                )
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
        )
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var selectedTabContent: some View {
        switch viewModel.selectedTab {
        case .weight: weightContent
        case .food: foodContent
        case .activity: activityContent
        }
    }

    // MARK: - Weight Content

    private var weightContent: some View {
        VStack(spacing: HubLayout.sectionSpacing) {
            // Current weight card
            HubCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Weight")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        if let latest = viewModel.latestWeight {
                            Text(latest.formattedWeight)
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        } else {
                            Text("No data")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }

                    Spacer()

                    if let change = viewModel.weeklyWeightChange {
                        weightChangeBadge(change: change)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier(AccessibilityID.healthCurrentWeight)

            // Weight timeline chart
            if viewModel.timelineWeights.count >= 2 {
                WeightTimelineChart(
                    entries: viewModel.timelineWeights,
                    weightRange: viewModel.weightRange
                )
            }

            // Log button
            HubButton("Log Weight", icon: "plus.circle.fill") {
                showWeightLog = true
            }
            .accessibilityIdentifier(AccessibilityID.healthLogWeightButton)

            // Recent entries
            if !viewModel.weightEntries.isEmpty {
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: "Recent Entries")

                    let recentEntries = viewModel.weightEntries
                        .sorted { $0.date > $1.date }
                        .prefix(10)

                    ForEach(Array(recentEntries)) { entry in
                        weightEntryRow(entry)
                    }
                }
            }
        }
    }

    private func weightChangeBadge(change: Double) -> some View {
        let isGain = change > 0
        let color: Color = isGain ? .hubAccentRed : .hubAccentGreen
        let arrow = isGain ? "arrow.up.right" : "arrow.down.right"

        return HStack(spacing: 4) {
            Image(systemName: arrow)
                .font(.system(size: 12, weight: .bold))
            Text(String(format: "%+.1f kg", change))
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(color.opacity(0.12))
        )
    }

    private func weightEntryRow(_ entry: WeightEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.formattedWeight)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text(entry.formattedDate)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            if let note = entry.note, !note.isEmpty {
                Spacer()
                Text(note)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .lineLimit(1)
            } else {
                Spacer()
            }
        }
        .padding(HubLayout.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(AdaptiveColors.surface(for: colorScheme))
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.3)
                        : Color.black.opacity(0.06),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
    }

    // MARK: - Food Content

    private var foodContent: some View {
        VStack(spacing: HubLayout.sectionSpacing) {
            // Quick meal input with photo/camera
            quickMealLogSection

            // Inline image preview
            if let image = selectedImage {
                foodImagePreview(image)
            }

            // Inline analyzing indicator
            if isFoodAnalyzing {
                foodAnalyzingIndicator
            }

            // Inline error banner
            if let error = foodAnalysisError {
                foodErrorBanner(error)
            }

            // Inline analysis result
            if let result = foodAnalysisResult {
                foodAnalysisResultView(result)
            }

            // AI-powered daily summary
            DailySummaryView(viewModel: viewModel)

            if viewModel.todayFoodEntries.isEmpty && foodAnalysisResult == nil {
                emptyStateCard(
                    icon: "fork.knife",
                    message: "No meals logged today"
                )
            }
        }
    }

    /// Inline meal input with photo/camera buttons.
    private var quickMealLogSection: some View {
        VStack(spacing: 8) {
            // Text input row
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.hubPrimary)

                TextField("e.g., Beef noodles and bubble tea", text: $quickMealText)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .focused($isQuickMealFocused)
                    .accessibilityIdentifier(AccessibilityID.healthQuickMealInput)
                    .onSubmit {
                        submitQuickMeal()
                    }

                if !quickMealText.isEmpty {
                    Button {
                        submitQuickMeal()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.hubPrimary)
                    }
                    .accessibilityIdentifier(AccessibilityID.healthQuickMealSubmit)
                }
            }
            .padding(HubLayout.cardInnerPadding)
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

            // Action row: photo, camera
            HStack(spacing: 16) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 13, weight: .medium))
                        Text("Photo")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.hubPrimary)
                }
                .accessibilityIdentifier(AccessibilityID.healthPhotoButton)

                Button {
                    showCamera = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "camera")
                            .font(.system(size: 13, weight: .medium))
                        Text("Camera")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.hubPrimary)
                }
                .accessibilityIdentifier(AccessibilityID.healthCameraButton)

                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Inline Food Analysis Views

    private func foodImagePreview(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius))

            Button {
                selectedImage = nil
                selectedPhoto = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .padding(8)
        }
    }

    private var foodAnalyzingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Color.hubPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Analyzing your meal...")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Text("AI is estimating calories and nutrition")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            Spacer()
        }
        .padding(HubLayout.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(Color.hubPrimary.opacity(0.08))
        )
    }

    private func foodErrorBanner(_ error: String) -> some View {
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

    private func foodAnalysisResultView(_ result: FoodAnalysisResult) -> some View {
        VStack(spacing: HubLayout.itemSpacing) {
            // Summary header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Analysis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.hubPrimary)
                    Text(result.summary)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.hubPrimary)
            }
            .padding(HubLayout.cardInnerPadding)
            .background(
                RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                    .fill(Color.hubPrimary.opacity(0.06))
            )

            // Calories + macros
            HStack(spacing: 12) {
                macroCard(label: "Calories", value: "\(result.totalCalories)", unit: "kcal", color: .hubAccentYellow)
                macroCard(label: "Protein", value: "\(result.totalProtein)", unit: "g", color: .hubAccentRed)
                macroCard(label: "Carbs", value: "\(result.totalCarbs)", unit: "g", color: .hubPrimary)
                macroCard(label: "Fat", value: "\(result.totalFat)", unit: "g", color: .hubAccentGreen)
            }

            // Individual items
            if result.items.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Items")
                    ForEach(result.items) { item in
                        foodItemRow(item)
                    }
                }
            }

            // Save button
            HubButton("Save Meal", icon: "checkmark.circle.fill") {
                saveFoodResult(result)
            }
        }
    }

    private func macroCard(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color.opacity(0.7))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }

    private func foodItemRow(_ item: AnalyzedFoodItem) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.hubPrimary.opacity(0.3))
                .frame(width: 6, height: 6)

            Text(item.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            if let portion = item.portion {
                Text("(\(portion))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            Spacer()

            Text("\(item.calories) cal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.hubAccentYellow)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AdaptiveColors.surface(for: colorScheme))
        )
    }

    private func foodEntryRow(_ entry: FoodEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.mealType.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.hubPrimary)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(Color.hubPrimary.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.description)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(entry.mealType.displayName)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    Text(entry.formattedTime)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }

            Spacer()

            if let calories = entry.calories {
                Text("\(calories) cal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.hubAccentYellow)
            }
        }
        .padding(HubLayout.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(AdaptiveColors.surface(for: colorScheme))
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.3)
                        : Color.black.opacity(0.06),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
    }

    // MARK: - Food Actions

    private func submitQuickMeal() {
        let trimmed = quickMealText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        foodAnalysisDescription = trimmed
        quickMealText = ""
        isQuickMealFocused = false
        foodAnalysisResult = nil
        foodAnalysisError = nil
        foodAnalysisDate = Date()
        isFoodAnalyzing = true
        Task {
            let result = await foodAnalysisService.analyzeText(trimmed)
            isFoodAnalyzing = false
            foodAnalysisError = foodAnalysisService.analysisError
            foodAnalysisResult = result
        }
    }

    private func analyzeFoodInput() async {
        foodAnalysisResult = nil
        foodAnalysisError = nil
        foodAnalysisDate = Date()
        isFoodAnalyzing = true
        if let image = selectedImage {
            let context = quickMealText.isEmpty ? nil : quickMealText
            foodAnalysisDescription = quickMealText
            let result = await foodAnalysisService.analyzeImage(image, context: context)
            isFoodAnalyzing = false
            foodAnalysisError = foodAnalysisService.analysisError
            foodAnalysisResult = result
        } else {
            let trimmed = quickMealText.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                isFoodAnalyzing = false
                return
            }
            foodAnalysisDescription = trimmed
            let result = await foodAnalysisService.analyzeText(trimmed)
            isFoodAnalyzing = false
            foodAnalysisError = foodAnalysisService.analysisError
            foodAnalysisResult = result
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            selectedImage = image
            await analyzeFoodInput()
        }
    }

    private func saveFoodResult(_ result: FoodAnalysisResult) {
        let description = foodAnalysisDescription.isEmpty
            ? result.summary
            : foodAnalysisDescription
        viewModel.addFoodFromAnalysis(result, description: description, date: foodAnalysisDate)
        // Clear state
        foodAnalysisResult = nil
        foodAnalysisError = nil
        foodAnalysisDescription = ""
        selectedImage = nil
        selectedPhoto = nil
        quickMealText = ""
    }

    // MARK: - Activity Content

    private var activityContent: some View {
        VStack(spacing: HubLayout.sectionSpacing) {
            // Quick activity input
            quickActivityLogSection

            // Inline analyzing indicator
            if isActivityAnalyzing {
                activityAnalyzingIndicator
            }

            // Inline error banner
            if let error = activityAnalysisError {
                activityErrorBanner(error)
            }

            // Inline activity analysis result
            if let result = activityAnalysisResult {
                activityAnalysisResultView(result)
            }

            // Today's summary
            HubCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Activity")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(viewModel.todayActivityCalories)")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            Text("kcal")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(viewModel.todayActivityEntries.count) activities")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        if viewModel.todayActivityMinutes > 0 {
                            Text("\(viewModel.todayActivityMinutes) min")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier(AccessibilityID.healthTodayActivity)

            // Today's activities
            if !viewModel.todayActivityEntries.isEmpty {
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: "Today's Activities")

                    ForEach(viewModel.todayActivityEntries) { entry in
                        activityEntryRow(entry)
                    }
                }
            } else if activityAnalysisResult == nil {
                emptyStateCard(
                    icon: "figure.run",
                    message: "No activities logged today"
                )
            }
        }
    }

    /// AI-powered activity input.
    private var quickActivityLogSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.hubAccentGreen)

            TextField("e.g., Walked 30 min to campus", text: $quickActivityText)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .focused($isQuickActivityFocused)
                .accessibilityIdentifier(AccessibilityID.healthQuickActivityInput)
                .onSubmit {
                    submitQuickActivity()
                }

            if !quickActivityText.isEmpty {
                Button {
                    submitQuickActivity()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.hubAccentGreen)
                }
                .accessibilityIdentifier(AccessibilityID.healthQuickActivitySubmit)
            }
        }
        .padding(HubLayout.cardInnerPadding)
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
    }

    // MARK: - Inline Activity Analysis Views

    private var activityAnalyzingIndicator: some View {
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

    private func activityErrorBanner(_ error: String) -> some View {
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

    private func activityAnalysisResultView(_ result: ActivityAnalysisResult) -> some View {
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

            // Exercise breakdown
            if let exercises = result.exercises, !exercises.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Exercises")
                    ForEach(exercises) { exercise in
                        exerciseItemRow(exercise)
                    }
                }
            }

            // Save button
            HubButton("Save Activity", icon: "checkmark.circle.fill") {
                saveActivityResult(result)
            }
        }
    }

    private func exerciseItemRow(_ exercise: ExerciseItem) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.hubAccentGreen.opacity(0.3))
                .frame(width: 6, height: 6)

            Text(exercise.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Spacer()

            HStack(spacing: 6) {
                if let sets = exercise.sets, let reps = exercise.reps {
                    Text("\(sets)×\(reps)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.hubPrimary)
                }

                if let weight = exercise.weight {
                    Text(weight)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                if let duration = exercise.duration {
                    Text("\(duration) min")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                if let cal = exercise.caloriesBurned {
                    Text("~\(cal) cal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.hubAccentYellow)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AdaptiveColors.surface(for: colorScheme))
        )
    }

    // MARK: - Activity Actions

    private func submitQuickActivity() {
        let trimmed = quickActivityText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        activityAnalysisDescription = trimmed
        quickActivityText = ""
        isQuickActivityFocused = false
        activityAnalysisResult = nil
        activityAnalysisError = nil
        activityAnalysisDate = Date()
        isActivityAnalyzing = true
        Task {
            let result = await foodAnalysisService.analyzeActivity(trimmed)
            isActivityAnalyzing = false
            activityAnalysisError = foodAnalysisService.analysisError
            activityAnalysisResult = result
        }
    }

    private func saveActivityResult(_ result: ActivityAnalysisResult) {
        let description = activityAnalysisDescription.isEmpty
            ? result.summary
            : activityAnalysisDescription
        viewModel.addActivityFromAnalysis(result, description: description, date: activityAnalysisDate)
        activityAnalysisResult = nil
        activityAnalysisError = nil
        activityAnalysisDescription = ""
        quickActivityText = ""
    }

    // MARK: - Shared

    private func activityEntryRow(_ entry: ActivityEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ActivityParser.icon(for: entry.type))
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.hubAccentGreen)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(Color.hubAccentGreen.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                if let rawDesc = entry.rawDescription, !rawDesc.isEmpty {
                    Text(rawDesc)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .lineLimit(2)
                } else {
                    Text(entry.type)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }

                HStack(spacing: 8) {
                    if entry.rawDescription != nil {
                        Text(entry.type)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.hubAccentGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.hubAccentGreen.opacity(0.12))
                            )
                    }

                    if entry.duration > 0 {
                        Text(entry.formattedDuration)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Text(entry.formattedTime)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }

            Spacer()

            if let calories = entry.caloriesBurned, calories > 0 {
                Text("\(calories) cal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.hubAccentYellow)
            } else if entry.rawDescription == nil, let note = entry.note, !note.isEmpty {
                Text(note)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .lineLimit(1)
            }
        }
        .padding(HubLayout.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(AdaptiveColors.surface(for: colorScheme))
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.3)
                        : Color.black.opacity(0.06),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
    }

    // MARK: - Empty State

    private func emptyStateCard(icon: String, message: String) -> some View {
        HubCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                Text(message)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HealthView()
    }
}
