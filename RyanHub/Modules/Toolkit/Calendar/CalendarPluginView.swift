import SwiftUI

// MARK: - Calendar Plugin View

/// Main calendar view showing upcoming events organized by day,
/// with week overview, countdown timer, event details, and sync state.
struct CalendarPluginView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = CalendarViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                if !viewModel.hasSynced && !viewModel.hasAnyEvents {
                    emptyStateView
                } else {
                    syncHeader
                    countdownSection
                    weekOverviewSection
                    todaySection
                    tomorrowSection
                    thisWeekSection
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.refresh()
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.hubPrimary)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.hubPrimary)
                    }
                }
                .disabled(viewModel.isLoading)
                .accessibilityIdentifier(AccessibilityID.calendarRefreshButton)
            }
        }
        .sheet(isPresented: $viewModel.showEventDetail) {
            if let event = viewModel.selectedEvent {
                EventDetailView(event: event, colorScheme: colorScheme)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.hubPrimary.opacity(0.6))

            VStack(spacing: 8) {
                Text("No Events Yet")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text("Sync with Google Calendar to see your schedule here. Events are fetched through the Dispatcher.")
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            HubButton("Sync with Google Calendar", icon: "arrow.triangle.2.circlepath", isLoading: viewModel.isLoading) {
                viewModel.syncEvents()
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
            .accessibilityIdentifier(AccessibilityID.calendarSyncButton)

            Spacer()
                .frame(height: 40)
        }
        .accessibilityIdentifier(AccessibilityID.calendarEmptyState)
    }

    // MARK: - Sync Header

    private var syncHeader: some View {
        Group {
            if let syncLabel = viewModel.lastSyncLabel {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .medium))
                    Text(syncLabel)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
        }
    }

    // MARK: - Countdown Section

    @ViewBuilder
    private var countdownSection: some View {
        if let event = viewModel.nextUpcomingEvent,
           let countdown = viewModel.countdownToNextEvent {
            HubCard {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(event.resolvedColor)
                        .frame(width: 4, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Up")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .textCase(.uppercase)

                        Text(event.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(countdown)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(event.isOngoing ? Color.hubAccentGreen : Color.hubPrimary)

                        Text(event.formattedStartTime)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier(AccessibilityID.calendarCountdown)
        }
    }

    // MARK: - Week Overview

    @ViewBuilder
    private var weekOverviewSection: some View {
        if viewModel.hasAnyEvents {
            VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                SectionHeader(title: "Week Overview")

                HubCard {
                    HStack(spacing: 0) {
                        ForEach(viewModel.weekOverview) { block in
                            weekDayColumn(block: block)
                            if block.date != viewModel.weekOverview.last?.date {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityIdentifier(AccessibilityID.calendarWeekOverview)
        }
    }

    private func weekDayColumn(block: WeekDayBlock) -> some View {
        VStack(spacing: 6) {
            Text(block.dayLabel)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(
                    block.isToday
                        ? Color.hubPrimary
                        : AdaptiveColors.textSecondary(for: colorScheme)
                )

            Text(block.dayNumber)
                .font(.system(size: 13, weight: block.isToday ? .bold : .regular))
                .foregroundStyle(
                    block.isToday
                        ? .white
                        : AdaptiveColors.textPrimary(for: colorScheme)
                )
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(block.isToday ? Color.hubPrimary : Color.clear)
                )

            // Busy indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(busyColor(for: block))
                .frame(width: 24, height: busyHeight(for: block))

            Text(block.events.count > 0 ? "\(block.events.count)" : "-")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(
                    block.events.isEmpty
                        ? AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4)
                        : AdaptiveColors.textSecondary(for: colorScheme)
                )
        }
        .frame(maxWidth: .infinity)
    }

    private func busyColor(for block: WeekDayBlock) -> Color {
        if block.events.isEmpty {
            return AdaptiveColors.surfaceSecondary(for: colorScheme)
        }
        if block.busyHours >= 4 {
            return Color.hubAccentRed.opacity(0.6)
        }
        if block.busyHours >= 2 {
            return Color.hubAccentYellow.opacity(0.6)
        }
        return Color.hubAccentGreen.opacity(0.6)
    }

    private func busyHeight(for block: WeekDayBlock) -> CGFloat {
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 32
        if block.events.isEmpty { return minHeight }
        let ratio = min(block.busyHours / 8.0, 1.0)
        return minHeight + CGFloat(ratio) * (maxHeight - minHeight)
    }

    // MARK: - Today Section

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            HStack {
                SectionHeader(title: CalendarSection.today.displayTitle)

                Spacer()

                Text(formattedToday)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            if viewModel.todayEvents.isEmpty {
                emptyDayCard(message: "No events today")
            } else {
                ForEach(viewModel.todayEvents) { event in
                    Button {
                        viewModel.selectEvent(event)
                    } label: {
                        eventCard(event)
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.calendarTodaySection)
    }

    // MARK: - Tomorrow Section

    private var tomorrowSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            HStack {
                SectionHeader(title: CalendarSection.tomorrow.displayTitle)

                Spacer()

                Text(formattedTomorrow)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            if viewModel.tomorrowEvents.isEmpty {
                emptyDayCard(message: "No events tomorrow")
            } else {
                ForEach(viewModel.tomorrowEvents) { event in
                    Button {
                        viewModel.selectEvent(event)
                    } label: {
                        eventCard(event)
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.calendarTomorrowSection)
    }

    // MARK: - This Week Section

    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: CalendarSection.thisWeek.displayTitle)

            if viewModel.weekEvents.isEmpty {
                emptyDayCard(message: "No other events this week")
            } else {
                ForEach(viewModel.weekEvents) { event in
                    Button {
                        viewModel.selectEvent(event)
                    } label: {
                        eventCard(event)
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.calendarThisWeekSection)
    }

    // MARK: - Event Card

    private func eventCard(_ event: CalendarEvent) -> some View {
        HStack(spacing: 12) {
            // Calendar color indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(event.resolvedColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        event.hasEnded
                            ? AdaptiveColors.textSecondary(for: colorScheme)
                            : AdaptiveColors.textPrimary(for: colorScheme)
                    )
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Label(event.formattedTimeRange, systemImage: "clock")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // Time badge for quick glance
                if !event.isAllDay {
                    Text(event.formattedStartTime)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(event.resolvedColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(event.resolvedColor.opacity(0.12))
                        )
                } else {
                    Text("All Day")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.hubAccentYellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.hubAccentYellow.opacity(0.12))
                        )
                }

                // Ongoing indicator
                if event.isOngoing {
                    Text("Now")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.hubAccentGreen)
                }
            }
        }
        .padding(HubLayout.cardInnerPadding)
        .frame(minHeight: 60)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(AdaptiveColors.surface(for: colorScheme))
                .overlay(
                    event.isOngoing
                        ? RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                            .stroke(Color.hubAccentGreen.opacity(0.3), lineWidth: 1)
                        : nil
                )
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

    private func emptyDayCard(message: String) -> some View {
        HubCard {
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                Text(message)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Date Helpers

    private var formattedToday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    private var formattedTomorrow: String {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: tomorrow)
    }
}

// MARK: - Event Detail View

/// Shows full details of a calendar event in a sheet.
struct EventDetailView: View {
    let event: CalendarEvent
    let colorScheme: ColorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Color bar + title
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(event.resolvedColor)
                            .frame(width: 6)

                        Text(event.title)
                            .font(.hubTitle)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    }
                    .frame(height: 40)

                    // Time details
                    VStack(alignment: .leading, spacing: 12) {
                        detailRow(
                            icon: "clock",
                            title: "Time",
                            value: event.formattedTimeRange
                        )

                        detailRow(
                            icon: "hourglass",
                            title: "Duration",
                            value: event.formattedDuration
                        )

                        detailRow(
                            icon: "calendar",
                            title: "Date",
                            value: event.formattedFullDate
                        )

                        // Location with map link
                        if let location = event.location, !location.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                detailRow(
                                    icon: "mappin.and.ellipse",
                                    title: "Location",
                                    value: location
                                )

                                if let url = event.mapsURL {
                                    Link(destination: url) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "map")
                                                .font(.system(size: 12, weight: .medium))
                                            Text("Open in Maps")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundStyle(Color.hubPrimary)
                                        .padding(.leading, 36)
                                    }
                                }
                            }
                        }

                        // Notes
                        if let notes = event.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                detailRow(
                                    icon: "note.text",
                                    title: "Notes",
                                    value: ""
                                )

                                Text(notes)
                                    .font(.hubBody)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                    .padding(.leading, 36)
                            }
                        }
                    }

                    // Status badge
                    if event.isOngoing {
                        HStack {
                            Spacer()
                            Text("Currently Happening")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.hubAccentGreen)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.hubAccentGreen.opacity(0.12))
                                )
                            Spacer()
                        }
                    } else if event.hasEnded {
                        HStack {
                            Spacer()
                            Text("Event Ended")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                                )
                            Spacer()
                        }
                    }
                }
                .padding(HubLayout.standardPadding)
            }
            .background(AdaptiveColors.background(for: colorScheme))
        }
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.hubPrimary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .textCase(.uppercase)

                if !value.isEmpty {
                    Text(value)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CalendarPluginView()
    }
}
