import SwiftUI

// MARK: - Health View

/// Main health tracking view with tabs for weight, food, and activity.
struct HealthView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = HealthViewModel()
    @State private var showWeightLog = false
    @State private var showSmartFoodLog = false
    @State private var showActivityLog = false

    // Quick activity natural language input
    @State private var quickActivityText = ""
    @State private var quickActivityParsed: ActivityParser.ParseResult?
    @FocusState private var isQuickActivityFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                tabSelector
                selectedTabContent
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .sheet(isPresented: $showWeightLog) {
            WeightLogView(viewModel: viewModel)
        }
        .sheet(isPresented: $showSmartFoodLog) {
            SmartFoodLogView(viewModel: viewModel)
        }
        .sheet(isPresented: $showActivityLog) {
            ActivityLogSheet(viewModel: viewModel)
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(HealthTab.allCases) { tab in
                Button {
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
            // AI-powered daily summary
            DailySummaryView(viewModel: viewModel)

            // Smart log button
            Button {
                showSmartFoodLog = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            LinearGradient(
                                colors: [Color.hubPrimary, Color.hubPrimaryLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Log a Meal")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Text("Describe or snap a photo — AI handles the rest")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
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
            .buttonStyle(.plain)

            if viewModel.todayFoodEntries.isEmpty {
                emptyStateCard(
                    icon: "fork.knife",
                    message: "No meals logged today"
                )
            }
        }
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

    // MARK: - Activity Content

    private var activityContent: some View {
        VStack(spacing: HubLayout.sectionSpacing) {
            // Today's summary
            HubCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Activity")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(viewModel.todayActivityMinutes)")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            Text("min")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }

                    Spacer()

                    Text("\(viewModel.todayActivityEntries.count) activities")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Natural language quick log
            quickActivityLogSection

            // Structured log button (fallback)
            HubSecondaryButton("Structured Log", icon: "list.bullet") {
                showActivityLog = true
            }

            // Today's activities
            if !viewModel.todayActivityEntries.isEmpty {
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: "Today's Activities")

                    ForEach(viewModel.todayActivityEntries) { entry in
                        activityEntryRow(entry)
                    }
                }
            } else {
                emptyStateCard(
                    icon: "figure.run",
                    message: "No activities logged today"
                )
            }
        }
    }

    /// Natural language activity input with live parsing preview.
    private var quickActivityLogSection: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            // Text input
            HStack(spacing: 10) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.hubAccentGreen)

                TextField("e.g., Walked 30 min to campus", text: $quickActivityText)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .focused($isQuickActivityFocused)
                    .onSubmit {
                        submitQuickActivity()
                    }
                    .onChange(of: quickActivityText) { _, newValue in
                        if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                            quickActivityParsed = nil
                        } else {
                            quickActivityParsed = ActivityParser.parse(newValue)
                        }
                    }

                if !quickActivityText.isEmpty {
                    Button {
                        submitQuickActivity()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.hubAccentGreen)
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
                        radius: 8, x: 0, y: 2
                    )
            )

            // Live parsing preview
            if let parsed = quickActivityParsed {
                HStack(spacing: 12) {
                    Image(systemName: ActivityParser.icon(for: parsed.type))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.hubAccentGreen)

                    Text(parsed.type)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    if let duration = parsed.duration {
                        Text("\(duration) min")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color.hubPrimary.opacity(0.12))
                            )
                    } else {
                        Text("30 min (default)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                            )
                    }

                    Spacer()
                }
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeOut(duration: 0.15), value: quickActivityParsed?.type)
            }
        }
    }

    private func submitQuickActivity() {
        let trimmed = quickActivityText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        viewModel.addActivityFromDescription(trimmed)

        withAnimation(.easeOut(duration: 0.2)) {
            quickActivityText = ""
            quickActivityParsed = nil
        }
        isQuickActivityFocused = false
    }

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
                // Show raw description if from natural language, otherwise show type
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
                    // Show parsed type tag if from natural language
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

                    Text(entry.formattedDuration)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    Text(entry.formattedTime)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }

            Spacer()

            // Only show note for structured entries (non-NL)
            if entry.rawDescription == nil, let note = entry.note, !note.isEmpty {
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

// MARK: - Activity Log Sheet

/// Sheet for logging a new activity entry.
struct ActivityLogSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let viewModel: HealthViewModel

    @State private var activityType = ""
    @State private var durationText = ""
    @State private var note = ""
    @State private var date = Date()

    private var isValid: Bool {
        !activityType.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Int(durationText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HubLayout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Activity Type")
                        HubTextField(placeholder: "e.g., Running, Walking, Gym", text: $activityType)
                    }

                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Duration (minutes)")
                        HubTextField(placeholder: "30", text: $durationText)
                            .keyboardType(.numberPad)
                    }

                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Date & Time")
                        DatePicker("", selection: $date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(.hubPrimary)
                    }

                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Note (Optional)")
                        HubTextField(placeholder: "Add a note...", text: $note)
                    }

                    HubButton(L10n.commonSave, icon: "checkmark") {
                        guard let duration = Int(durationText) else { return }
                        viewModel.addActivity(
                            type: activityType.trimmingCharacters(in: .whitespaces),
                            duration: duration,
                            date: date,
                            note: note.isEmpty ? nil : note
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.5)
                }
                .padding(HubLayout.standardPadding)
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                        .foregroundStyle(Color.hubPrimary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HealthView()
    }
}
