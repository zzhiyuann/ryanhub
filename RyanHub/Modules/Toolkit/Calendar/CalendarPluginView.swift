import SwiftUI

// MARK: - Calendar Plugin View

/// Main calendar view with real Google Calendar integration.
/// Shows events organized by day with an AI-powered command input bar.
struct CalendarPluginView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var viewModel = CalendarViewModel()
    @FocusState private var isInputFocused: Bool

    @State private var showCommandSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                dateHeader

                if !viewModel.hasSynced && !viewModel.hasAnyEvents {
                    emptyStateView
                } else {
                    countdownSection
                    weekOverviewSection
                    agentResponseSection
                    todaySection
                    tomorrowSection
                    thisWeekSection
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .refreshable {
            await viewModel.syncEvents()
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .alert("Delete Event", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.executeDeleteEvent() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.eventToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete \"\(viewModel.eventToDelete?.title ?? "")\"? This will also remove it from Google Calendar.")
        }
        .sheet(isPresented: $viewModel.showEventDetail) {
            if let event = viewModel.selectedEvent {
                EventDetailView(
                    event: event,
                    colorScheme: colorScheme,
                    onDelete: {
                        Task { await viewModel.deleteEvent(event) }
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showCommandSheet) {
            CalendarCommandSheet(viewModel: viewModel, colorScheme: colorScheme)
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            updateServiceURL()
        }
        .task {
            updateServiceURL()
            await viewModel.syncEvents()
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    // Large day number with accent
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(formattedDayNumber)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.hubPrimary, Color.hubPrimaryLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(formattedDayOfWeek)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            Text(formattedMonthYear)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }
                }

                Spacer()

                // Action buttons
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        // AI command button
                        Button { showCommandSheet = true } label: {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.hubPrimary)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color.hubPrimary.opacity(0.1))
                                )
                        }

                        // Sync button
                        Button {
                            updateServiceURL()
                            viewModel.isLoading = false
                            Task { await viewModel.syncEvents() }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(Color.hubPrimary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(Color.hubPrimary.opacity(0.1))
                                    )
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.hubPrimary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(Color.hubPrimary.opacity(0.1))
                                    )
                            }
                        }
                    }

                    // Subtle sync status
                    if let syncLabel = viewModel.lastSyncLabel {
                        Text(syncLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.7))
                    } else if case .error = viewModel.syncState {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.hubAccentRed)
                                .frame(width: 5, height: 5)
                            Text("Sync error")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.hubAccentRed.opacity(0.8))
                        }
                    }
                }
            }

            // Today's event count summary
            if viewModel.hasAnyEvents {
                let todayCount = viewModel.todayEvents.count
                let remaining = viewModel.todayEvents.filter { !$0.hasEnded }.count
                HStack(spacing: 6) {
                    Circle()
                        .fill(remaining > 0 ? Color.hubAccentGreen : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3))
                        .frame(width: 6, height: 6)
                    Text(todaySummaryText(total: todayCount, remaining: remaining))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
                .padding(.top, 2)
            }
        }
    }

    private func todaySummaryText(total: Int, remaining: Int) -> String {
        if total == 0 {
            return "Nothing on the agenda today"
        } else if remaining == 0 {
            return "All \(total) event\(total == 1 ? "" : "s") completed"
        } else {
            return "\(remaining) event\(remaining == 1 ? "" : "s") remaining today"
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 32)

            // Animated calendar icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.hubPrimary.opacity(0.15), Color.hubPrimaryLight.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.hubPrimary, Color.hubPrimaryLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 10) {
                Text("Your Schedule Awaits")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text("Connect your calendar to see upcoming events, get smart reminders, and manage your day with AI.")
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .lineSpacing(3)
            }

            HubButton("Sync Calendar", icon: "arrow.triangle.2.circlepath", isLoading: viewModel.isLoading) {
                Task { await viewModel.syncEvents() }
            }
            .padding(.horizontal, 48)
            .padding(.top, 4)

            Spacer().frame(height: 32)
        }
    }

    // MARK: - Countdown Section

    @ViewBuilder
    private var countdownSection: some View {
        if let event = viewModel.nextUpcomingEvent,
           let countdown = viewModel.countdownToNextEvent {
            let isOngoing = event.isOngoing
            let accentColor = isOngoing ? Color.hubAccentGreen : Color.hubPrimary

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    // Left: color indicator + event info
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [event.resolvedColor, event.resolvedColor.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: 48)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("NEXT UP")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(accentColor.opacity(0.8))
                                .tracking(1.2)

                            if isOngoing {
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(Color.hubAccentGreen)
                                        .frame(width: 5, height: 5)
                                    Text("LIVE")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.hubAccentGreen)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.hubAccentGreen.opacity(0.12))
                                )
                            }
                        }

                        Text(event.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10, weight: .medium))
                            Text(event.formattedTimeRange)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    // Right: countdown badge
                    VStack(spacing: 2) {
                        Text(countdown)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(accentColor.opacity(0.1))
                    )
                }
                .padding(HubLayout.cardInnerPadding)
            }
            .background(
                RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                    .fill(AdaptiveColors.surface(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                            .stroke(accentColor.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.4)
                            : accentColor.opacity(0.08),
                        radius: 12, x: 0, y: 4
                    )
            )
        }
    }

    // MARK: - Week Overview

    @ViewBuilder
    private var weekOverviewSection: some View {
        if viewModel.hasAnyEvents {
            VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                calendarSectionHeader(title: "This Week", icon: "calendar.day.timeline.leading")

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
        }
    }

    private func weekDayColumn(block: WeekDayBlock) -> some View {
        VStack(spacing: 5) {
            Text(block.dayLabel.prefix(1).uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(
                    block.isToday
                        ? Color.hubPrimary
                        : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.6)
                )
                .tracking(0.5)

            ZStack {
                if block.isToday {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.hubPrimary, Color.hubPrimaryLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                }

                Text(block.dayNumber)
                    .font(.system(size: 14, weight: block.isToday ? .bold : .medium, design: .rounded))
                    .foregroundStyle(
                        block.isToday
                            ? .white
                            : AdaptiveColors.textPrimary(for: colorScheme)
                    )
            }
            .frame(width: 32, height: 32)

            // Activity indicator dots
            HStack(spacing: 2) {
                let count = min(block.events.count, 3)
                if count > 0 {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle()
                            .fill(busyColor(for: block))
                            .frame(width: 4, height: 4)
                    }
                } else {
                    Circle()
                        .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 6)

            if !block.events.isEmpty {
                Text("\(block.events.count)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(busyColor(for: block))
            } else {
                Text("\u{2013}")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(
                        AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func busyColor(for block: WeekDayBlock) -> Color {
        if block.events.isEmpty { return AdaptiveColors.surfaceSecondary(for: colorScheme) }
        if block.busyHours >= 4 { return Color.hubAccentRed }
        if block.busyHours >= 2 { return Color.hubAccentYellow }
        return Color.hubAccentGreen
    }

    // MARK: - Agent Response Section

    @ViewBuilder
    private var agentResponseSection: some View {
        if viewModel.isProcessingCommand {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(Color.hubPrimary)
                Text("Processing command...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                Spacer()
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

        if let response = viewModel.agentResponse {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: response.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(response.isError ? Color.hubAccentRed : Color.hubAccentGreen)

                VStack(alignment: .leading, spacing: 2) {
                    Text(response.isError ? "Error" : "Done")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(response.isError ? Color.hubAccentRed : Color.hubAccentGreen)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(response.message)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .lineSpacing(2)
                }

                Spacer()

                Button {
                    viewModel.dismissAgentResponse()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                        )
                }
            }
            .padding(HubLayout.cardInnerPadding)
            .background(
                RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                    .fill(AdaptiveColors.surface(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                            .stroke(
                                (response.isError ? Color.hubAccentRed : Color.hubAccentGreen).opacity(0.15),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.3)
                            : Color.black.opacity(0.06),
                        radius: 8, x: 0, y: 2
                    )
            )
        }

        if let error = viewModel.commandError {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.hubAccentRed)
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.hubAccentRed.opacity(0.9))
                    .lineLimit(2)
                Spacer()
                Button {
                    viewModel.dismissAgentResponse()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                        )
                }
            }
            .padding(HubLayout.cardInnerPadding)
            .background(
                RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                    .fill(AdaptiveColors.surface(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                            .stroke(Color.hubAccentRed.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.3)
                            : Color.black.opacity(0.06),
                        radius: 8, x: 0, y: 2
                    )
            )
        }
    }

    // MARK: - Today Section

    @State private var showEndedEvents = false

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            calendarSectionHeader(
                title: CalendarSection.today.displayTitle,
                icon: "sun.max.fill",
                trailing: formattedToday
            )

            if viewModel.todayEvents.isEmpty && viewModel.todayEndedEvents.isEmpty {
                emptyDayCard(
                    message: "Your day is wide open",
                    subtitle: "Enjoy the free time or add something new",
                    icon: "sun.min.fill"
                )
            } else if viewModel.todayEvents.isEmpty && !viewModel.todayEndedEvents.isEmpty {
                emptyDayCard(
                    message: "All done for today",
                    subtitle: "\(viewModel.todayEndedEvents.count) event\(viewModel.todayEndedEvents.count == 1 ? "" : "s") completed",
                    icon: "checkmark.circle.fill"
                )
            }

            // Upcoming/ongoing events
            ForEach(viewModel.todayEvents) { event in
                Button { viewModel.selectEvent(event) } label: {
                    eventCard(event)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        viewModel.confirmDeleteEvent(event)
                    } label: {
                        Label("Delete Event", systemImage: "trash")
                    }
                }
            }

            // Collapsed ended events
            if !viewModel.todayEndedEvents.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showEndedEvents.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showEndedEvents ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(viewModel.todayEndedEvents.count) earlier event\(viewModel.todayEndedEvents.count == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.6))
                    .padding(.vertical, 4)
                }

                if showEndedEvents {
                    ForEach(viewModel.todayEndedEvents) { event in
                        Button { viewModel.selectEvent(event) } label: {
                            eventCard(event)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.confirmDeleteEvent(event)
                            } label: {
                                Label("Delete Event", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tomorrow Section

    private var tomorrowSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            calendarSectionHeader(
                title: CalendarSection.tomorrow.displayTitle,
                icon: "sunrise.fill",
                trailing: formattedTomorrow
            )

            if viewModel.tomorrowEvents.isEmpty {
                emptyDayCard(
                    message: "Tomorrow is clear",
                    subtitle: "No events scheduled yet",
                    icon: "moon.stars.fill"
                )
            } else {
                ForEach(viewModel.tomorrowEvents) { event in
                    Button { viewModel.selectEvent(event) } label: {
                        eventCard(event)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.confirmDeleteEvent(event)
                        } label: {
                            Label("Delete Event", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - This Week Section

    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            calendarSectionHeader(
                title: CalendarSection.thisWeek.displayTitle,
                icon: "calendar.day.timeline.left"
            )

            if viewModel.weekEvents.isEmpty {
                emptyDayCard(
                    message: "Rest of the week is open",
                    subtitle: "No upcoming events beyond tomorrow",
                    icon: "leaf.fill"
                )
            } else {
                ForEach(viewModel.eventsByDay, id: \.date) { dayGroup in
                    VStack(alignment: .leading, spacing: 8) {
                        // Day group header
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.hubPrimary.opacity(0.3))
                                .frame(width: 2, height: 14)
                            Text(dayGroup.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                        .padding(.leading, 4)

                        ForEach(dayGroup.events) { event in
                            Button { viewModel.selectEvent(event) } label: {
                                eventCard(event)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.confirmDeleteEvent(event)
                                } label: {
                                    Label("Delete Event", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Section Header Helper

    private func calendarSectionHeader(title: String, icon: String, trailing: String? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.hubPrimary.opacity(0.7))

            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                .tracking(1)

            // Subtle line
            Rectangle()
                .fill(AdaptiveColors.border(for: colorScheme))
                .frame(height: 0.5)

            if let trailing = trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.6))
            }
        }
    }

    // MARK: - Event Card

    private func eventCard(_ event: CalendarEvent) -> some View {
        HStack(spacing: 0) {
            // Left color bar
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [event.resolvedColor, event.resolvedColor.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)
                .padding(.vertical, 8)

            HStack(spacing: 12) {
                // Time column
                VStack(spacing: 2) {
                    if event.isAllDay {
                        Text("ALL")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.hubAccentYellow)
                        Text("DAY")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.hubAccentYellow)
                    } else {
                        Text(formattedHour(from: event.startTime))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                event.hasEnded
                                    ? AdaptiveColors.textSecondary(for: colorScheme)
                                    : event.resolvedColor
                            )
                        Text(formattedMinuteAndPeriod(from: event.startTime))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(
                                event.hasEnded
                                    ? AdaptiveColors.textSecondary(for: colorScheme).opacity(0.6)
                                    : event.resolvedColor.opacity(0.7)
                            )
                    }
                }
                .frame(width: 36)

                // Divider dot
                Circle()
                    .fill(event.resolvedColor.opacity(0.3))
                    .frame(width: 4, height: 4)

                // Event details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(event.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                event.hasEnded
                                    ? AdaptiveColors.textSecondary(for: colorScheme)
                                    : AdaptiveColors.textPrimary(for: colorScheme)
                            )
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if event.isOngoing {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color.hubAccentGreen)
                                    .frame(width: 5, height: 5)
                                Text("Now")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.hubAccentGreen)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.hubAccentGreen.opacity(0.12))
                            )
                        }
                    }

                    HStack(spacing: 10) {
                        // Duration badge
                        if !event.isAllDay {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9, weight: .medium))
                                Text(event.formattedDuration)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }

                        // Location / Meeting link
                        if let location = event.location, !location.isEmpty {
                            HStack(spacing: 3) {
                                let isLink = location.hasPrefix("http")
                                Image(systemName: isLink ? "video.fill" : "mappin.circle.fill")
                                    .font(.system(size: 9, weight: .medium))
                                Text(isLink ? "Join Meeting" : location)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }

                    // Calendar name tag
                    if let calName = event.calendarName, !calName.isEmpty {
                        Text(calName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(event.resolvedColor.opacity(0.9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(event.resolvedColor.opacity(0.1))
                            )
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .padding(.trailing, HubLayout.cardInnerPadding)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(
                    event.isOngoing
                        ? AdaptiveColors.surface(for: colorScheme)
                            .opacity(1)
                        : AdaptiveColors.surface(for: colorScheme)
                )
                .overlay(
                    // Subtle tinted background from calendar color
                    RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                        .fill(event.resolvedColor.opacity(colorScheme == .dark ? 0.04 : 0.03))
                )
                .overlay(
                    event.isOngoing
                        ? RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                            .stroke(Color.hubAccentGreen.opacity(0.25), lineWidth: 1)
                        : nil
                )
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.35)
                        : event.resolvedColor.opacity(0.06),
                    radius: 10, x: 0, y: 3
                )
        )
        .opacity(event.hasEnded ? 0.7 : 1.0)
    }

    // MARK: - Empty Day Card

    private func emptyDayCard(message: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.hubPrimary.opacity(0.5), Color.hubPrimaryLight.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme).opacity(0.7))
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.6))
            }

            Spacer()
        }
        .padding(HubLayout.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(AdaptiveColors.surface(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                        .strokeBorder(
                            AdaptiveColors.border(for: colorScheme),
                            style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                        )
                )
        )
    }

    // Command input bar removed — replaced by sparkle button + sheet

    // MARK: - Date Helpers

    private var formattedDayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: Date())
    }

    private var formattedDayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }

    private var formattedMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }

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

    private func formattedHour(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h"
        return formatter.string(from: date)
    }

    private func formattedMinuteAndPeriod(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm a"
        return formatter.string(from: date)
    }

    /// Set the calendar service URL to use the bridge server proxy.
    private func updateServiceURL() {
        // Route through bridge server (:18790/calendar/*) which is proven reachable
        let bridgeHost = URL(string: appState.foodAnalysisURL)?.host ?? "100.89.67.80"
        let url = "http://\(bridgeHost):18790/calendar"
        viewModel.service.bridgeBaseURL = url
    }
}

// MARK: - Event Detail View

/// Shows full details of a calendar event in a sheet.
struct EventDetailView: View {
    let event: CalendarEvent
    let colorScheme: ColorScheme
    var onDelete: (() -> Void)?
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with color accent
                    VStack(alignment: .leading, spacing: 12) {
                        Text(event.title)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(event.resolvedColor)

                        if let calName = event.calendarName {
                            Text(calName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(event.resolvedColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(event.resolvedColor.opacity(0.12))
                                )
                        }
                    }

                    // Status badge
                    if event.isOngoing {
                        statusBadge(text: "Currently Happening", color: .hubAccentGreen)
                    } else if event.hasEnded {
                        statusBadge(text: "Event Ended", color: AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        detailRow(icon: "clock", title: "Time", value: event.formattedTimeRange)
                        detailRow(icon: "hourglass", title: "Duration", value: event.formattedDuration)
                        detailRow(icon: "calendar", title: "Date", value: event.formattedFullDate)

                        if let location = event.location, !location.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                // Check if location is a URL (meeting link)
                                if let meetingURL = URL(string: location),
                                   let scheme = meetingURL.scheme,
                                   scheme.hasPrefix("http") {
                                    detailRow(icon: "video.fill", title: "Meeting Link", value: "")
                                    Link(destination: meetingURL) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "link")
                                                .font(.system(size: 12, weight: .medium))
                                            Text(location)
                                                .font(.system(size: 13, weight: .medium))
                                                .lineLimit(1)
                                        }
                                        .foregroundStyle(Color.hubPrimary)
                                        .padding(.leading, 36)
                                    }
                                } else {
                                    detailRow(icon: "mappin.and.ellipse", title: "Location", value: location)
                                    if let url = event.mapsURL {
                                        Link(destination: url) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "map.fill")
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
                        }

                        if let notes = event.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                detailRow(icon: "note.text", title: "Notes", value: "")
                                Text(notes)
                                    .font(.hubBody)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                    .padding(.leading, 36)
                                    .padding(.trailing, 4)
                                    .lineSpacing(3)
                            }
                        }

                        // Attendees
                        if let attendees = event.attendees, !attendees.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                detailRow(icon: "person.2.fill", title: "Attendees (\(attendees.count))", value: "")
                                ForEach(attendees, id: \.email) { attendee in
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(attendee.statusColor)
                                            .frame(width: 8, height: 8)
                                        Text(attendee.displayName ?? attendee.email)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                        Spacer()
                                        Text(attendee.statusLabel)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(attendee.statusColor)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(
                                                Capsule()
                                                    .fill(attendee.statusColor.opacity(0.12))
                                            )
                                    }
                                    .padding(.leading, 36)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // Actions
                    HStack(spacing: 12) {
                        if let url = event.googleCalendarURL {
                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.right.square")
                                    Text("Open in Google Calendar")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.hubPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.hubPrimary.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.hubPrimary.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                        }

                        Spacer()

                        if onDelete != nil {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.hubAccentRed)
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.hubAccentRed.opacity(0.08))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.hubAccentRed.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(HubLayout.standardPadding)
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .alert("Delete Event", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \"\(event.title)\"?")
            }
        }
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.hubPrimary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .textCase(.uppercase)
                    .tracking(0.5)

                if !value.isEmpty {
                    Text(value)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
            }
        }
    }

    private func statusBadge(text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            if color == .hubAccentGreen {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Calendar Command Sheet

/// A compact sheet for entering AI calendar commands.
struct CalendarCommandSheet: View {
    let viewModel: CalendarViewModel
    let colorScheme: ColorScheme
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var commandText = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.hubPrimary)
                Text("Calendar AI")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4))
                }
            }

            HStack(spacing: 10) {
                TextField("e.g. Add lunch with Laura tomorrow at noon", text: $commandText)
                    .font(.system(size: 15))
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit { send() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                    )

                Button(action: send) {
                    if viewModel.isProcessingCommand {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 40, height: 40)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                    }
                }
                .background(
                    Circle()
                        .fill(commandText.trimmingCharacters(in: .whitespaces).isEmpty
                              ? Color.hubPrimary.opacity(0.4)
                              : Color.hubPrimary)
                )
                .clipShape(Circle())
                .disabled(commandText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isProcessingCommand)
            }
        }
        .padding(20)
        .background(AdaptiveColors.surface(for: colorScheme))
        .onAppear { isFocused = true }
    }

    private func send() {
        let text = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        viewModel.commandText = text
        commandText = ""
        dismiss()
        Task { await viewModel.processCommand() }
    }
}

// MARK: - Preview

#Preview {
    CalendarPluginView()
        .environment(AppState())
}
