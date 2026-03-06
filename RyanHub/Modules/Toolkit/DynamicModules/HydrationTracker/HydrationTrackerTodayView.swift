import SwiftUI

struct HydrationTrackerTodayView: View {
    let viewModel: HydrationTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var animatedProgress: Double = 0
    @State private var showCelebration = false
    @State private var celebrationScale: CGFloat = 0
    @State private var isShowingCustomEntry = false

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                heroSection
                quickAddSection
                drinkTypeSelectorSection
                todayTimelineSection
                weeklyChartSection
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, 32)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = viewModel.goalProgress
            }
            if viewModel.goalReached {
                triggerCelebration()
            }
        }
        .onChange(of: viewModel.goalProgress) { _, newValue in
            withAnimation(.easeOut(duration: 0.6)) {
                animatedProgress = newValue
            }
        }
        .onChange(of: viewModel.goalReached) { _, reached in
            if reached {
                triggerCelebration()
            }
        }
        .sheet(isPresented: $isShowingCustomEntry) {
            customEntrySheet
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                ZStack {
                    ProgressRingView(
                        progress: min(animatedProgress, 1.0),
                        current: "\(viewModel.todayIntake)",
                        unit: "ml",
                        goal: "of \(viewModel.dailyGoal) ml",
                        color: viewModel.goalReached ? Color.hubAccentGreen : Color.hubPrimary,
                        size: 180,
                        lineWidth: 14
                    )

                    if showCelebration {
                        celebrationBurst
                    }
                }
                .padding(.top, 8)

                if !viewModel.goalReached {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.hubPrimary.opacity(0.7))
                        Text("\(viewModel.remainingMl) ml remaining")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    .padding(.bottom, 4)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.hubAccentGreen)
                        Text("Daily goal reached!")
                            .font(.hubBody)
                            .foregroundStyle(Color.hubAccentGreen)
                    }
                    .padding(.bottom, 4)
                }
            }
        }
    }

    // MARK: - Celebration Burst

    private var celebrationBurst: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) * 45.0
                let radians = angle * .pi / 180
                Circle()
                    .fill(celebrationColor(for: index))
                    .frame(width: 8, height: 8)
                    .offset(
                        x: cos(radians) * 110 * celebrationScale,
                        y: sin(radians) * 110 * celebrationScale
                    )
                    .opacity(Double(1.0 - celebrationScale))
            }

            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) * 45.0 + 22.5
                let radians = angle * .pi / 180
                Circle()
                    .fill(celebrationColor(for: index + 3))
                    .frame(width: 5, height: 5)
                    .offset(
                        x: cos(radians) * 90 * celebrationScale,
                        y: sin(radians) * 90 * celebrationScale
                    )
                    .opacity(Double(1.0 - celebrationScale))
            }
        }
    }

    private func celebrationColor(for index: Int) -> Color {
        let colors: [Color] = [
            Color.hubAccentGreen,
            Color.hubAccentYellow,
            Color.hubPrimary,
            .cyan,
            Color.hubAccentGreen,
            Color.hubAccentYellow,
            Color.hubPrimary,
            .mint
        ]
        return colors[index % colors.count]
    }

    private func triggerCelebration() {
        showCelebration = true
        celebrationScale = 0
        withAnimation(.easeOut(duration: 0.8)) {
            celebrationScale = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showCelebration = false
            celebrationScale = 0
        }
    }

    // MARK: - Quick Add Section

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Quick Add")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(HydrationPreset.defaults) { preset in
                        Button {
                            Task { await viewModel.quickAdd(preset: preset) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: iconSize(for: preset.amount)))
                                    .foregroundStyle(Color.hubPrimary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(preset.label)
                                        .font(.hubCaption)
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                    Text("\(preset.amount)ml")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.hubPrimary.opacity(0.1))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.hubPrimary.opacity(0.25), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func iconSize(for amount: Int) -> CGFloat {
        switch amount {
        case ...200: return 12
        case 201...250: return 14
        case 251...350: return 16
        default: return 18
        }
    }

    // MARK: - Drink Type Selector

    private var drinkTypeSelectorSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Drink Type")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DrinkType.allCases) { type in
                        Button {
                            viewModel.selectedDrinkType = type
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 18))
                                Text(type.displayName)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .frame(width: 58, height: 54)
                            .foregroundStyle(
                                viewModel.selectedDrinkType == type
                                    ? Color.white
                                    : AdaptiveColors.textSecondary(for: colorScheme)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        viewModel.selectedDrinkType == type
                                            ? Color.hubPrimary
                                            : Color.hubPrimary.opacity(0.08)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        isShowingCustomEntry = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                            Text("Custom")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(width: 58, height: 54)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3),
                                    style: StrokeStyle(lineWidth: 1, dash: [4])
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Custom Entry Sheet

    @State private var customAmount: String = ""
    @State private var customDrinkType: DrinkType = .water

    private var customEntrySheet: some View {
        QuickEntrySheet(
            title: "Custom Amount",
            icon: "drop.fill",
            saveLabel: "Add",
            canSave: (Int(customAmount) ?? 0) > 0,
            onSave: {
                if let amount = Int(customAmount), amount > 0 {
                    Task { await viewModel.quickAddAmount(amount, drinkType: customDrinkType) }
                }
                customAmount = ""
                isShowingCustomEntry = false
            }
        ) {
            EntryFormSection(title: "Amount (ml)") {
                HubTextField(placeholder: "Enter amount in ml", text: $customAmount)
                    .keyboardType(.numberPad)
            }

            EntryFormSection(title: "Drink Type") {
                Picker("Type", selection: $customDrinkType) {
                    ForEach(DrinkType.allCases) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.hubPrimary)
            }

            HStack(spacing: 8) {
                ForEach([100, 200, 300, 500], id: \.self) { amount in
                    Button {
                        customAmount = "\(amount)"
                    } label: {
                        Text("\(amount)")
                            .font(.hubCaption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(
                                        customAmount == "\(amount)"
                                            ? Color.hubPrimary
                                            : Color.hubPrimary.opacity(0.1)
                                    )
                            )
                            .foregroundStyle(
                                customAmount == "\(amount)"
                                    ? Color.white
                                    : Color.hubPrimary
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            customDrinkType = viewModel.selectedDrinkType
        }
    }

    // MARK: - Today Timeline

    private var todayTimelineSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Today's Intake")

            if viewModel.todayEntries.isEmpty {
                HubCard {
                    VStack(spacing: 8) {
                        Image(systemName: "drop")
                            .font(.system(size: 28))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5))
                        Text("No entries yet today")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Text("Tap a quick-add button above to log a drink")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.todayEntries) { entry in
                        timelineRow(for: entry)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius))
            }
        }
    }

    private func timelineRow(for entry: HydrationTrackerEntry) -> some View {
        HubCard {
            HStack(spacing: 12) {
                Image(systemName: entry.drinkType.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.hubPrimary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.hubPrimary.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.drinkType.displayName)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    Text(entry.formattedTime)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                Spacer()

                Text("\(entry.amount) ml")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.hubPrimary)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await viewModel.deleteEntry(entry) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Weekly Chart Section

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "This Week")

            HubCard {
                VStack(alignment: .leading, spacing: 16) {
                    weeklyBarChart

                    Divider()
                        .opacity(0.3)

                    HStack(spacing: HubLayout.standardPadding) {
                        streakBadge
                        Spacer()
                        weeklyAverageStat
                    }
                }
            }
        }
    }

    private var weeklyBarChart: some View {
        let summaries = viewModel.weeklySummaries
        let maxValue = max(Double(viewModel.dailyGoal), Double(summaries.map(\.total).max() ?? 0))

        return VStack(spacing: 8) {
            GeometryReader { geo in
                let barWidth = (geo.size.width - CGFloat(summaries.count - 1) * 6) / CGFloat(max(summaries.count, 1))
                let chartHeight = geo.size.height

                ZStack(alignment: .bottom) {
                    // Goal dashed line
                    let goalY = maxValue > 0
                        ? chartHeight * (1.0 - Double(viewModel.dailyGoal) / maxValue)
                        : 0

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: goalY))
                        path.addLine(to: CGPoint(x: geo.size.width, y: goalY))
                    }
                    .stroke(
                        AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 3])
                    )

                    // Bars
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(summaries) { day in
                            let barHeight = maxValue > 0
                                ? chartHeight * Double(day.total) / maxValue
                                : 0

                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(day.metGoal ? Color.hubAccentGreen : Color.hubPrimary.opacity(0.35))
                                    .frame(width: barWidth, height: max(barHeight, 2))
                            }
                        }
                    }
                }
            }
            .frame(height: 120)

            // Day labels
            HStack(spacing: 6) {
                ForEach(summaries) { day in
                    Text(day.dayLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var streakBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16))
                .foregroundStyle(viewModel.currentStreak > 0 ? Color.hubAccentYellow : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4))

            VStack(alignment: .leading, spacing: 1) {
                Text("\(viewModel.currentStreak)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Text("day streak")
                    .font(.system(size: 11))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
        }
    }

    private var weeklyAverageStat: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("\(viewModel.weeklyAverage)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            Text("ml avg/day")
                .font(.system(size: 11))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
    }
}