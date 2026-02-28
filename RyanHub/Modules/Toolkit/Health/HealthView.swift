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
    @State private var selectedDate: Date = Date()

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

    // Exercise input sheet state
    @State private var showExerciseInput = false
    @State private var exerciseTargetActivityID: UUID?
    @State private var exerciseName = ""
    @State private var exerciseSets: Int = 3
    @State private var exerciseReps: Int = 10
    @State private var exerciseWeightValue = ""
    @State private var exerciseWeightUnit: WeightUnit = .lb
    @State private var exerciseDuration: Int = 0
    @State private var exerciseIsCardio = false
    @State private var exerciseNameSuggestions: [String] = []

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
        .sheet(isPresented: $showExerciseInput) {
            exerciseInputSheet
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
            viewModel.requestHealthKitAccess()
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
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        viewModel.deleteWeight(entry)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
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
            // Day navigation
            DateNavigationBar(selectedDate: $selectedDate)

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

            // AI-powered daily summary (date-aware)
            DailySummaryView(viewModel: viewModel, selectedDate: $selectedDate)

            if viewModel.foodEntries(for: selectedDate).isEmpty && foodAnalysisResult == nil {
                emptyStateCard(
                    icon: "fork.knife",
                    message: noMealsMessage
                )
            }
        }
    }

    /// Empty state message for meals, reflecting the selected date.
    private var noMealsMessage: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "No meals logged today"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "No meals logged yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "No meals logged on \(formatter.string(from: selectedDate))"
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

            // Save / Decline buttons
            HStack(spacing: 12) {
                HubSecondaryButton("Decline") {
                    declineFoodResult()
                }

                HubButton("Save Meal", icon: "checkmark.circle.fill") {
                    saveFoodResult(result)
                }
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
                Text(entry.displayName)
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

    /// Decline the AI analysis result without saving.
    private func declineFoodResult() {
        foodAnalysisResult = nil
        foodAnalysisError = nil
        foodAnalysisDescription = ""
        selectedImage = nil
        selectedPhoto = nil
    }

    // MARK: - Activity Content

    /// Activity entries for the selected day.
    private var selectedDayActivityEntries: [ActivityEntry] {
        viewModel.activityEntries(for: selectedDate)
    }

    /// Activity summary label reflecting the selected date.
    private var activitySummaryLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Today's Activity"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday's Activity"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: selectedDate)) Activity"
        }
    }

    /// Section header for activities list.
    private var activitiesSectionTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Today's Activities"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday's Activities"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "Activities on \(formatter.string(from: selectedDate))"
        }
    }

    /// Empty state message for activities.
    private var noActivitiesMessage: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "No activities logged today"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "No activities logged yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "No activities logged on \(formatter.string(from: selectedDate))"
        }
    }

    private var activityContent: some View {
        VStack(spacing: HubLayout.sectionSpacing) {
            // Day navigation
            DateNavigationBar(selectedDate: $selectedDate)

            // Quick activity input
            quickActivityLogSection

            // Apple Health step count card (only show for today)
            if Calendar.current.isDateInToday(selectedDate) {
                stepsCard
            }

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

            // Day summary (for non-today dates without rings)
            if !Calendar.current.isDateInToday(selectedDate) {
                HubCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activitySummaryLabel)
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                let loggedCal = viewModel.activityCalories(for: selectedDate)
                                Text("\(loggedCal)")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                Text("kcal")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(selectedDayActivityEntries.count) activities")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            let actMinutes = viewModel.activityMinutes(for: selectedDate)
                            if actMinutes > 0 {
                                Text("\(actMinutes) min")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier(AccessibilityID.healthTodayActivity)
            }

            // Day's activities
            if !selectedDayActivityEntries.isEmpty {
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: activitiesSectionTitle)

                    ForEach(selectedDayActivityEntries) { entry in
                        activityEntryRow(entry)
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        viewModel.deleteActivity(entry)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            } else if activityAnalysisResult == nil {
                emptyStateCard(
                    icon: "figure.run",
                    message: noActivitiesMessage
                )
            }
        }
    }

    // MARK: - Activity Rings Card

    /// Daily goals for ring progress calculation.
    private static let stepGoal: Double = 10000
    private static let calorieGoal: Double = 500
    private static let activityMinuteGoal: Double = 30

    /// Card with activity rings (steps, calories, active minutes) — Apple Watch style.
    private var stepsCard: some View {
        let steps = Double(viewModel.todaySteps)
        let totalCal = Double(viewModel.todayActivityCalories + viewModel.stepsCaloriesBurned)
        let activeMin = Double(viewModel.todayActivityMinutes)

        return HubCard {
            HStack(spacing: 20) {
                // Activity rings
                ZStack {
                    // Active minutes ring (outer)
                    activityRing(
                        progress: min(activeMin / Self.activityMinuteGoal, 1.0),
                        color: Color.hubPrimary,
                        lineWidth: 8,
                        size: 100
                    )
                    // Calories ring (middle)
                    activityRing(
                        progress: min(totalCal / Self.calorieGoal, 1.0),
                        color: Color.hubAccentYellow,
                        lineWidth: 8,
                        size: 76
                    )
                    // Steps ring (inner)
                    activityRing(
                        progress: min(steps / Self.stepGoal, 1.0),
                        color: Color.hubAccentGreen,
                        lineWidth: 8,
                        size: 52
                    )
                }
                .frame(width: 100, height: 100)

                // Stats
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.isLoadingSteps {
                        ProgressView()
                            .tint(Color.hubAccentGreen)
                    } else {
                        // Steps
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.hubAccentGreen)
                                .frame(width: 8, height: 8)
                            Text(viewModel.todaySteps.formatted())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            Text("steps")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }

                        // Calories
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.hubAccentYellow)
                                .frame(width: 8, height: 8)
                            Text("\(Int(totalCal))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            Text("kcal")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }

                        // Active minutes
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.hubPrimary)
                                .frame(width: 8, height: 8)
                            Text("\(Int(activeMin))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            Text("min")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier(AccessibilityID.healthStepsCard)
    }

    /// A single activity ring (circular progress).
    private func activityRing(progress: Double, color: Color, lineWidth: CGFloat, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
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

            // Save / Decline buttons
            HStack(spacing: 12) {
                HubSecondaryButton("Decline") {
                    declineActivityResult()
                }

                HubButton("Save Activity", icon: "checkmark.circle.fill") {
                    saveActivityResult(result)
                }
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

    /// Decline the AI activity analysis result without saving.
    private func declineActivityResult() {
        activityAnalysisResult = nil
        activityAnalysisError = nil
        activityAnalysisDescription = ""
    }

    // MARK: - Shared

    private func activityEntryRow(_ entry: ActivityEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main activity header
            HStack(spacing: 12) {
                // Activity icon with optional Watch badge overlay
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: ActivityParser.icon(for: entry.type))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.hubAccentGreen)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(Color.hubAccentGreen.opacity(0.12))
                        )

                    // Apple Watch badge
                    if entry.isFromWatch {
                        Image(systemName: "applewatch")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.hubPrimary))
                            .offset(x: 4, y: 4)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    if entry.isFromWatch {
                        Text(entry.type)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    } else if let rawDesc = entry.rawDescription, !rawDesc.isEmpty {
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
                        if !entry.isFromWatch && entry.rawDescription != nil {
                            Text(entry.type)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.hubAccentGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(Color.hubAccentGreen.opacity(0.12))
                                )
                        }

                        if entry.isFromWatch {
                            Text("Watch")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.hubPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(Color.hubPrimary.opacity(0.12))
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

                VStack(alignment: .trailing, spacing: 4) {
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

                    // Add exercise button
                    Button {
                        openExerciseInput(for: entry.id)
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.hubPrimary)
                    }
                }
            }

            // Exercises list (below the main row)
            if !entry.exercises.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                        .padding(.vertical, 8)

                    ForEach(entry.exercises) { exercise in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.hubAccentGreen.opacity(0.4))
                                .frame(width: 5, height: 5)

                            Text(exercise.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                            Spacer()

                            HStack(spacing: 6) {
                                if let sets = exercise.sets, let reps = exercise.reps {
                                    Text("\(sets)x\(reps)")
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
                        .padding(.vertical, 2)
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.removeExercise(exercise.id, from: entry.id)
                                }
                            } label: {
                                Label("Delete Exercise", systemImage: "trash")
                            }
                        }
                    }
                }
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

    // MARK: - Exercise Input

    /// Open the exercise input sheet for a given activity entry.
    private func openExerciseInput(for activityID: UUID) {
        exerciseTargetActivityID = activityID
        exerciseName = ""
        exerciseSets = 3
        exerciseReps = 10
        exerciseWeightValue = ""
        exerciseWeightUnit = .lb
        exerciseDuration = 0
        exerciseIsCardio = false
        exerciseNameSuggestions = viewModel.recentExerciseNames
        showExerciseInput = true
    }

    /// Save the current exercise input to the target activity.
    private func saveExercise() {
        guard let activityID = exerciseTargetActivityID else { return }
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let weightString: String? = {
            let trimmed = exerciseWeightValue.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            return "\(trimmed) \(exerciseWeightUnit.rawValue)"
        }()

        let exercise = ExerciseItem(
            name: trimmedName,
            sets: exerciseIsCardio ? nil : exerciseSets,
            reps: exerciseIsCardio ? nil : exerciseReps,
            weight: exerciseIsCardio ? nil : weightString,
            duration: exerciseIsCardio ? (exerciseDuration > 0 ? exerciseDuration : nil) : nil
        )

        viewModel.addExercise(exercise, to: activityID)
        showExerciseInput = false
    }

    /// Exercise input sheet view.
    private var exerciseInputSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Exercise name with autocomplete suggestions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EXERCISE NAME")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        TextField("e.g., Lat Pulldown", text: $exerciseName)
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                            )

                        // Recent exercise name suggestions
                        if !exerciseNameSuggestions.isEmpty && exerciseName.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(exerciseNameSuggestions.prefix(8), id: \.self) { suggestion in
                                        Button {
                                            exerciseName = suggestion
                                        } label: {
                                            Text(suggestion)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(Color.hubPrimary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule().fill(Color.hubPrimary.opacity(0.1))
                                                )
                                        }
                                    }
                                }
                            }
                        }

                        // Filtered suggestions while typing
                        if !exerciseName.isEmpty {
                            let filtered = exerciseNameSuggestions.filter {
                                $0.localizedCaseInsensitiveContains(exerciseName) && $0.lowercased() != exerciseName.lowercased()
                            }
                            if !filtered.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(filtered.prefix(5), id: \.self) { suggestion in
                                            Button {
                                                exerciseName = suggestion
                                            } label: {
                                                Text(suggestion)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(Color.hubPrimary)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        Capsule().fill(Color.hubPrimary.opacity(0.1))
                                                    )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Strength / Cardio toggle
                    Picker("Type", selection: $exerciseIsCardio) {
                        Text("Strength").tag(false)
                        Text("Cardio").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if exerciseIsCardio {
                        // Cardio: duration
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DURATION (MINUTES)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                            Stepper(value: $exerciseDuration, in: 0...300, step: 5) {
                                Text("\(exerciseDuration) min")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                            )
                        }
                    } else {
                        // Strength: sets, reps, weight
                        HStack(spacing: 16) {
                            // Sets
                            VStack(alignment: .leading, spacing: 8) {
                                Text("SETS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                                Stepper(value: $exerciseSets, in: 1...20) {
                                    Text("\(exerciseSets)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                                )
                            }

                            // Reps
                            VStack(alignment: .leading, spacing: 8) {
                                Text("REPS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                                Stepper(value: $exerciseReps, in: 1...100) {
                                    Text("\(exerciseReps)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                                )
                            }
                        }

                        // Weight input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WEIGHT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                            HStack(spacing: 10) {
                                TextField("e.g., 70", text: $exerciseWeightValue)
                                    .font(.hubBody)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                    .keyboardType(.decimalPad)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                                    )

                                Picker("Unit", selection: $exerciseWeightUnit) {
                                    ForEach(WeightUnit.allCases) { unit in
                                        Text(unit.displayName).tag(unit)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 100)
                            }
                        }
                    }

                    // Save button
                    HubButton("Add Exercise", icon: "plus.circle.fill") {
                        saveExercise()
                    }
                    .disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }
                .padding(HubLayout.standardPadding)
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showExerciseInput = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
