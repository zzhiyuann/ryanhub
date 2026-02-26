import SwiftUI

// MARK: - Parking View

/// Main parking management view.
/// Shows today's status with a progress ring, interactive calendar picker,
/// cost tracker, smart suggestions, and skip history.
struct ParkingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = ParkingViewModel()
    @State private var showHistory = false

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                todayStatusCard
                smartSuggestionSection
                calendarPickerSection
                savingsSection
                upcomingSkipsSection
                skipHistorySection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .overlay(alignment: .bottom) {
            if viewModel.showConfirmation, let message = viewModel.lastActionMessage {
                confirmationBanner(message: message)
            }
        }
    }

    // MARK: - Today Status Card

    private var todayStatusCard: some View {
        HubCard {
            VStack(spacing: 12) {
                // Main status row
                HStack(spacing: 14) {
                    // Countdown ring when active, static icon otherwise
                    if viewModel.todayStatus == .active {
                        let remaining = viewModel.parkingTimeRemaining
                        ZStack {
                            Circle()
                                .stroke(
                                    AdaptiveColors.surfaceSecondary(for: colorScheme),
                                    lineWidth: 5
                                )
                            Circle()
                                .trim(from: 0, to: CGFloat(remaining.fraction))
                                .stroke(
                                    Color.hubAccentGreen,
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                            Text(remaining.label)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.hubAccentGreen)
                        }
                        .frame(width: 52, height: 52)
                    } else {
                        Image(systemName: todayIconName)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(todayIconColor)
                            .frame(width: 52, height: 52)
                            .background(
                                Circle()
                                    .fill(todayIconColor.opacity(0.12))
                            )
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(todayHeadline)
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        Text(todaySubline)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Spacer()
                }

                Divider()
                    .foregroundStyle(AdaptiveColors.border(for: colorScheme))

                // Monthly summary row
                HStack(spacing: 0) {
                    monthStatPill(
                        value: "\(viewModel.currentMonthStats.activeDays)",
                        label: "active",
                        color: .hubAccentGreen
                    )
                    Spacer()
                    monthStatPill(
                        value: "\(viewModel.currentMonthStats.skippedDays)",
                        label: "skipped",
                        color: .hubAccentYellow
                    )
                    Spacer()
                    monthStatPill(
                        value: "\(viewModel.currentMonthStats.totalWeekdays)",
                        label: "total",
                        color: AdaptiveColors.textSecondary(for: colorScheme)
                    )
                }
            }
        }
    }

    private func monthStatPill(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
    }

    private var todayHeadline: String {
        if !viewModel.isTodayWeekday {
            return "Weekend"
        }
        switch viewModel.todayStatus {
        case .active:
            if let duration = viewModel.lastCronStatus?.duration {
                return duration
            }
            return "Active"
        case .skipped:
            return "Skipped Today"
        case .notPurchased:
            return "Not Purchased"
        case .unknown:
            return "Pending"
        }
    }

    private var todaySubline: String {
        if !viewModel.isTodayWeekday {
            return "No parking needed"
        }
        switch viewModel.todayStatus {
        case .active:
            return "Zone 5556 · \(viewModel.parkingUntilTime)"
        case .skipped:
            return "Parking was skipped today"
        case .notPurchased:
            if let cron = viewModel.lastCronStatus, cron.isToday {
                return cron.summary
            }
            return "Cron has not run yet"
        case .unknown:
            return "Waiting for cron job"
        }
    }

    private var todayIconName: String {
        if !viewModel.isTodayWeekday { return "moon.zzz.fill" }
        switch viewModel.todayStatus {
        case .active: return "car.fill"
        case .skipped: return "arrow.right.circle.fill"
        case .notPurchased: return "exclamationmark.circle.fill"
        case .unknown: return "clock.fill"
        }
    }

    private var todayIconColor: Color {
        if !viewModel.isTodayWeekday { return AdaptiveColors.textSecondary(for: colorScheme) }
        switch viewModel.todayStatus {
        case .active: return .hubAccentGreen
        case .skipped: return .hubAccentYellow
        case .notPurchased: return .hubAccentRed
        case .unknown: return Color.hubPrimary
        }
    }

    // MARK: - Smart Suggestion

    @ViewBuilder
    private var smartSuggestionSection: some View {
        if let suggestion = viewModel.smartSuggestion {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.applySmartSuggestion()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        Text(suggestion.subtitle)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.hubPrimary)
                }
                .padding(HubLayout.cardInnerPadding)
                .background(
                    RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                        .fill(Color.hubPrimary.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                                .stroke(Color.hubPrimary.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: - Calendar Picker

    private var calendarPickerSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Skip Calendar")

            HubCard {
                VStack(spacing: 12) {
                    // Month navigation
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.previousMonth()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.hubPrimary)
                                .frame(width: 32, height: 32)
                        }

                        Spacer()

                        Text(viewModel.displayedMonthLabel)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        Spacer()

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.nextMonth()
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.hubPrimary)
                                .frame(width: 32, height: 32)
                        }
                    }

                    // Weekday headers (Mon-Sun)
                    let weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                        ForEach(weekdays.indices, id: \.self) { index in
                            Text(weekdays[index])
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                .frame(height: 24)
                        }
                    }

                    // Day grid
                    let days = viewModel.calendarDays
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                        ForEach(days.indices, id: \.self) { index in
                            if let date = days[index] {
                                calendarDayCell(date: date)
                            } else {
                                Color.clear
                                    .frame(height: 36)
                            }
                        }
                    }

                    // Legend
                    HStack(spacing: 16) {
                        legendItem(color: .hubPrimary, label: "Today")
                        legendItem(color: .hubAccentYellow, label: "Skipped")
                        legendItem(color: AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3), label: "Weekend")
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func calendarDayCell(date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isSkipped = viewModel.isDateSkipped(date)
        let isWeekend = calendar.isDateInWeekend(date)
        let isPast = calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
        let dayNumber = calendar.component(.day, from: date)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.toggleDate(date)
            }
        } label: {
            Text("\(dayNumber)")
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundStyle(dayTextColor(isToday: isToday, isSkipped: isSkipped, isWeekend: isWeekend, isPast: isPast))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(dayBackgroundColor(isToday: isToday, isSkipped: isSkipped))
                )
        }
        .disabled(isWeekend || isPast)
    }

    private func dayTextColor(isToday: Bool, isSkipped: Bool, isWeekend: Bool, isPast: Bool) -> Color {
        if isToday {
            return .white
        }
        if isSkipped {
            return .hubAccentYellow
        }
        if isWeekend || isPast {
            return AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4)
        }
        return AdaptiveColors.textPrimary(for: colorScheme)
    }

    private func dayBackgroundColor(isToday: Bool, isSkipped: Bool) -> Color {
        if isToday {
            return .hubPrimary
        }
        if isSkipped {
            return Color.hubAccentYellow.opacity(0.15)
        }
        return .clear
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Savings Tracker

    private var savingsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Cost Tracker")

            HubCard {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Estimated Savings")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                            Text(String(format: "$%.2f", viewModel.totalSavings))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Color.hubAccentGreen)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("This Month")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                            Text(String(format: "$%.2f", viewModel.currentMonthStats.estimatedSavings))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.hubAccentGreen)
                        }
                    }

                    Divider()
                        .foregroundStyle(AdaptiveColors.border(for: colorScheme))

                    HStack {
                        Label(
                            "\(viewModel.skipDates.count) total days skipped",
                            systemImage: "calendar.badge.minus"
                        )
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        Spacer()

                        Text("~$\(String(format: "%.2f", ParkingViewModel.costPerDay))/day")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Upcoming Skips

    private var upcomingSkipsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Upcoming Skip Dates")

            if viewModel.upcomingSkipDates.isEmpty {
                HubCard {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.hubAccentGreen)
                        Text("No upcoming skips")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.upcomingSkipDates) { entry in
                        skipDateRow(entry: entry)
                    }
                }
            }
        }
    }

    private func skipDateRow(entry: ParkingSkipEntry) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.hubAccentYellow)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.relativeDateLabel)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text(entry.formattedDate)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.restoreDate(entry)
                }
            } label: {
                Text("Restore")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.hubPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.hubPrimary.opacity(0.12))
                    )
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

    // MARK: - Skip History

    private var skipHistorySection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            if !viewModel.pastSkipDates.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showHistory.toggle()
                    }
                } label: {
                    HStack {
                        SectionHeader(title: "Skip History")

                        Spacer()

                        HStack(spacing: 4) {
                            Text("\(viewModel.pastSkipDates.count) past")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: showHistory ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }

                if showHistory {
                    VStack(spacing: 6) {
                        ForEach(viewModel.pastSkipDates.prefix(10)) { entry in
                            historyRow(entry: entry)
                        }

                        if viewModel.pastSkipDates.count > 10 {
                            Text("and \(viewModel.pastSkipDates.count - 10) more...")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                        }
                    }
                }
            }
        }
    }

    private func historyRow(entry: ParkingSkipEntry) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3))
                .frame(width: 6, height: 6)

            Text(entry.formattedDate)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Spacer()

            Text(String(format: "-$%.2f", ParkingViewModel.costPerDay))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.hubAccentGreen.opacity(0.7))
        }
        .padding(.horizontal, HubLayout.cardInnerPadding)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(AdaptiveColors.surface(for: colorScheme).opacity(0.5))
        )
    }

    // MARK: - Confirmation Banner

    private func confirmationBanner(message: String) -> some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.hubAccentGreen)
                    .shadow(color: Color.hubAccentGreen.opacity(0.3), radius: 8, y: 4)
            )
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.showConfirmation = false
                }
            }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ParkingView()
    }
}
