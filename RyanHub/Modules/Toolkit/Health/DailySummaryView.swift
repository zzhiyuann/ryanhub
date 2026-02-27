import SwiftUI

// MARK: - Daily Summary View

/// Beautiful daily nutrition summary showing meals timeline, macros breakdown, and calorie ring.
struct DailySummaryView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: HealthViewModel

    var body: some View {
        VStack(spacing: HubLayout.sectionSpacing) {
            calorieRingCard
            macrosBreakdown
            if !viewModel.todayFoodEntries.isEmpty {
                mealTimeline
            }
        }
    }

    // MARK: - Calorie Ring

    private var calorieRingCard: some View {
        HubCard {
            HStack(spacing: 20) {
                // Ring chart
                ZStack {
                    Circle()
                        .stroke(
                            AdaptiveColors.surfaceSecondary(for: colorScheme),
                            lineWidth: 10
                        )

                    Circle()
                        .trim(from: 0, to: calorieProgress)
                        .stroke(
                            calorieRingColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8), value: calorieProgress)

                    VStack(spacing: 2) {
                        Text("\(viewModel.todayCalories)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Text("kcal")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
                .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Intake")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(viewModel.todayCalories)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Text("/ \(calorieGoal) cal")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Text("\(viewModel.todayFoodEntries.count) meals logged")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    if viewModel.todayCalories > 0 {
                        Text(calorieStatusText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(calorieRingColor)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var calorieGoal: Int { 2000 }

    private var calorieProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(Double(viewModel.todayCalories) / Double(calorieGoal), 1.0)
    }

    private var calorieRingColor: Color {
        let ratio = Double(viewModel.todayCalories) / Double(calorieGoal)
        if ratio < 0.5 { return Color.hubAccentGreen }
        if ratio < 0.8 { return Color.hubPrimary }
        if ratio < 1.0 { return Color.hubAccentYellow }
        return Color.hubAccentRed
    }

    private var calorieStatusText: String {
        let remaining = calorieGoal - viewModel.todayCalories
        if remaining > 0 {
            return "\(remaining) cal remaining"
        } else {
            return "\(-remaining) cal over goal"
        }
    }

    // MARK: - Macros Breakdown

    private var macrosBreakdown: some View {
        HStack(spacing: 10) {
            macroBar(
                label: "Protein",
                value: viewModel.todayProtein,
                goal: 120,
                unit: "g",
                color: Color.hubAccentRed
            )
            macroBar(
                label: "Carbs",
                value: viewModel.todayCarbs,
                goal: 250,
                unit: "g",
                color: Color.hubPrimary
            )
            macroBar(
                label: "Fat",
                value: viewModel.todayFat,
                goal: 65,
                unit: "g",
                color: Color.hubAccentGreen
            )
        }
    }

    private func macroBar(label: String, value: Int, goal: Int, unit: String, color: Color) -> some View {
        VStack(spacing: 8) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: min(Double(value) / Double(goal), 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8), value: value)

                Text("\(value)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }
            .frame(width: 52, height: 52)

            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                Text("\(value)/\(goal)\(unit)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AdaptiveColors.surface(for: colorScheme))
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.3)
                        : Color.black.opacity(0.04),
                    radius: 6, x: 0, y: 2
                )
        )
    }

    // MARK: - Meal Timeline

    private var mealTimeline: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Today's Meals")

            ForEach(viewModel.todayFoodEntries) { entry in
                timelineRow(entry)
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation {
                                viewModel.deleteFood(entry)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private func timelineRow(_ entry: FoodEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline dot + line
            VStack(spacing: 0) {
                Circle()
                    .fill(mealColor(entry.mealType))
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(AdaptiveColors.border(for: colorScheme))
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 10)

            // Meal content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    // Meal type + time
                    HStack(spacing: 6) {
                        Image(systemName: entry.mealType.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(mealColor(entry.mealType))
                        Text(entry.mealType.displayName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(mealColor(entry.mealType))
                    }

                    Spacer()

                    Text(entry.formattedTime)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                Text(entry.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(2)

                // Nutrition badges
                HStack(spacing: 8) {
                    if let cal = entry.calories {
                        nutriBadge("\(cal) cal", color: .hubAccentYellow)
                    }
                    if let p = entry.protein, p > 0 {
                        nutriBadge("\(p)g P", color: .hubAccentRed)
                    }
                    if let c = entry.carbs, c > 0 {
                        nutriBadge("\(c)g C", color: .hubPrimary)
                    }
                    if let f = entry.fat, f > 0 {
                        nutriBadge("\(f)g F", color: .hubAccentGreen)
                    }
                }

                if entry.isAIAnalyzed {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                        Text("AI estimated")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(Color.hubPrimary.opacity(0.6))
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, HubLayout.cardInnerPadding)
    }

    private func nutriBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(color.opacity(0.1))
            )
    }

    private func mealColor(_ type: MealType) -> Color {
        switch type {
        case .breakfast: return Color.hubAccentYellow
        case .lunch: return Color.hubPrimary
        case .dinner: return Color.hubAccentRed
        case .snack: return Color.hubAccentGreen
        }
    }
}

#Preview {
    ScrollView {
        DailySummaryView(viewModel: HealthViewModel())
            .padding()
    }
}
