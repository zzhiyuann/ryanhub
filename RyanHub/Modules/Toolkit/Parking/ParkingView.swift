import SwiftUI

// MARK: - Parking View

/// Main parking management view.
/// Shows today's status with a progress ring, interactive calendar picker,
/// cost tracker, smart suggestions, and skip history.
struct ParkingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = ParkingViewModel()
    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                todayStatusCard
                calendarPickerSection
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
                        value: "\(viewModel.currentMonthStats.purchasedDays)",
                        label: "purchased",
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
                        value: "\(viewModel.currentMonthStats.awaitingDays)",
                        label: "awaiting",
                        color: AdaptiveColors.textSecondary(for: colorScheme)
                    )
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.parkingTodayStatus)
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
                        .accessibilityIdentifier(AccessibilityID.parkingPrevMonth)

                        Spacer()

                        Text(viewModel.displayedMonthLabel)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            .accessibilityIdentifier(AccessibilityID.parkingMonthLabel)

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
                        .accessibilityIdentifier(AccessibilityID.parkingNextMonth)
                    }

                    // Weekday headers (Sun-Sat)
                    let weekdays = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
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
                        legendItem(color: .hubAccentGreen, label: "Purchased")
                        legendItem(color: .hubAccentYellow, label: "Skipped")
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityIdentifier(AccessibilityID.parkingCalendar)
    }

    private func calendarDayCell(date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isSkipped = viewModel.isDateSkipped(date)
        let isPurchased = viewModel.isDatePurchased(date)
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
                .foregroundStyle(dayTextColor(isToday: isToday, isSkipped: isSkipped, isPurchased: isPurchased, isWeekend: isWeekend, isPast: isPast))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(dayBackgroundColor(isToday: isToday, isSkipped: isSkipped, isPurchased: isPurchased))
                )
        }
        .disabled(isWeekend || isPast)
    }

    private func dayTextColor(isToday: Bool, isSkipped: Bool, isPurchased: Bool, isWeekend: Bool, isPast: Bool) -> Color {
        if isToday {
            return .white
        }
        if isSkipped {
            return .hubAccentYellow
        }
        if isPurchased {
            return .hubAccentGreen
        }
        if isWeekend || isPast {
            return AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4)
        }
        return AdaptiveColors.textPrimary(for: colorScheme)
    }

    private func dayBackgroundColor(isToday: Bool, isSkipped: Bool, isPurchased: Bool) -> Color {
        if isToday {
            return .hubPrimary
        }
        if isSkipped {
            return Color.hubAccentYellow.opacity(0.15)
        }
        if isPurchased {
            return Color.hubAccentGreen.opacity(0.15)
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
            .accessibilityIdentifier(AccessibilityID.parkingConfirmation)
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
