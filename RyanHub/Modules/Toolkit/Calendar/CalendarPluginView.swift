import SwiftUI

// MARK: - Calendar Plugin View

/// Main calendar view with real Google Calendar integration.
/// Shows events organized by day with an AI-powered command input bar.
struct CalendarPluginView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var viewModel = CalendarViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content
            ScrollView {
                VStack(spacing: HubLayout.sectionSpacing) {
                    dateHeader
                    syncHeader

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
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                await viewModel.syncEvents()
            }

            // Fixed bottom input bar
            commandInputBar
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
        .task {
            viewModel.service.bridgeBaseURL = appState.calendarSyncURL
            await viewModel.syncEvents()
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedMonthYear)
                    .font(.hubTitle)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Text(formattedToday)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            Spacer()

            Button {
                Task { await viewModel.syncEvents() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(Color.hubPrimary)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                        .frame(width: 32, height: 32)
                }
            }
            .disabled(viewModel.isLoading)
        }
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
            } else if case .error(let msg) = viewModel.syncState {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.hubAccentRed)
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.hubAccentRed)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.hubPrimary.opacity(0.6))

            VStack(spacing: 8) {
                Text("No Events Yet")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text("Sync with Google Calendar to see your schedule. Use the input bar below to add events.")
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            HubButton("Sync with Google Calendar", icon: "arrow.triangle.2.circlepath", isLoading: viewModel.isLoading) {
                Task { await viewModel.syncEvents() }
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer().frame(height: 40)
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
                    Circle().fill(block.isToday ? Color.hubPrimary : Color.clear)
                )

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
        if block.events.isEmpty { return AdaptiveColors.surfaceSecondary(for: colorScheme) }
        if block.busyHours >= 4 { return Color.hubAccentRed.opacity(0.6) }
        if block.busyHours >= 2 { return Color.hubAccentYellow.opacity(0.6) }
        return Color.hubAccentGreen.opacity(0.6)
    }

    private func busyHeight(for block: WeekDayBlock) -> CGFloat {
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 32
        if block.events.isEmpty { return minHeight }
        let ratio = min(block.busyHours / 8.0, 1.0)
        return minHeight + CGFloat(ratio) * (maxHeight - minHeight)
    }

    // MARK: - Agent Response Section

    @ViewBuilder
    private var agentResponseSection: some View {
        if viewModel.isProcessingCommand {
            HubCard {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.hubPrimary)
                    Text("Processing command...")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        if let response = viewModel.agentResponse {
            HubCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: response.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(response.isError ? Color.hubAccentRed : Color.hubAccentGreen)

                    Text(response.message)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Spacer()

                    Button {
                        viewModel.dismissAgentResponse()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        if let error = viewModel.commandError {
            HubCard {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.hubAccentRed)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.hubAccentRed)
                    Spacer()
                    Button {
                        viewModel.dismissAgentResponse()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
            SectionHeader(title: CalendarSection.thisWeek.displayTitle)

            if viewModel.weekEvents.isEmpty {
                emptyDayCard(message: "No other events this week")
            } else {
                ForEach(viewModel.eventsByDay, id: \.date) { dayGroup in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dayGroup.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
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

    // MARK: - Event Card

    private func eventCard(_ event: CalendarEvent) -> some View {
        HStack(spacing: 12) {
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

                if let calName = event.calendarName, !calName.isEmpty {
                    Text(calName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(event.resolvedColor.opacity(0.8))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if !event.isAllDay {
                    Text(event.formattedStartTime)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(event.resolvedColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(event.resolvedColor.opacity(0.12)))
                } else {
                    Text("All Day")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.hubAccentYellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.hubAccentYellow.opacity(0.12)))
                }

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
                    radius: 8, x: 0, y: 2
                )
        )
    }

    // MARK: - Empty Day Card

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

    // MARK: - Command Input Bar

    private var commandInputBar: some View {
        VStack(spacing: 0) {
            // Top border
            AdaptiveColors.border(for: colorScheme)
                .frame(height: 0.5)

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.hubPrimary)

                TextField("Add event or ask about schedule...", text: $viewModel.commandText)
                    .font(.system(size: 15))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        Task { await viewModel.processCommand() }
                    }

                if !viewModel.commandText.isEmpty || viewModel.isProcessingCommand {
                    Button {
                        Task { await viewModel.processCommand() }
                    } label: {
                        if viewModel.isProcessingCommand {
                            ProgressView()
                                .tint(Color.hubPrimary)
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.hubPrimary)
                        }
                    }
                    .disabled(viewModel.isProcessingCommand || viewModel.commandText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Date Helpers

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
                VStack(alignment: .leading, spacing: 20) {
                    // Color bar + title
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(event.resolvedColor)
                            .frame(width: 6)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.hubTitle)
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            if let calName = event.calendarName {
                                Text(calName)
                                    .font(.hubCaption)
                                    .foregroundStyle(event.resolvedColor)
                            }
                        }
                    }
                    .frame(minHeight: 40)

                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        detailRow(icon: "clock", title: "Time", value: event.formattedTimeRange)
                        detailRow(icon: "hourglass", title: "Duration", value: event.formattedDuration)
                        detailRow(icon: "calendar", title: "Date", value: event.formattedFullDate)

                        if let location = event.location, !location.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                detailRow(icon: "mappin.and.ellipse", title: "Location", value: location)
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

                        if let notes = event.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                detailRow(icon: "note.text", title: "Notes", value: "")
                                Text(notes)
                                    .font(.hubBody)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                    .padding(.leading, 36)
                            }
                        }

                        // Attendees
                        if let attendees = event.attendees, !attendees.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                detailRow(icon: "person.2", title: "Attendees (\(attendees.count))", value: "")
                                ForEach(attendees, id: \.email) { attendee in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(attendee.statusColor.opacity(0.2))
                                            .frame(width: 8, height: 8)
                                        Text(attendee.displayName ?? attendee.email)
                                            .font(.system(size: 14))
                                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                        Spacer()
                                        Text(attendee.statusLabel)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(attendee.statusColor)
                                    }
                                    .padding(.leading, 36)
                                }
                            }
                        }
                    }

                    // Status badge
                    if event.isOngoing {
                        statusBadge(text: "Currently Happening", color: .hubAccentGreen)
                    } else if event.hasEnded {
                        statusBadge(text: "Event Ended", color: AdaptiveColors.textSecondary(for: colorScheme))
                    }

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
                                        .stroke(Color.hubPrimary.opacity(0.3), lineWidth: 1)
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
                                            .stroke(Color.hubAccentRed.opacity(0.3), lineWidth: 1)
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

    private func statusBadge(text: String, color: Color) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(color.opacity(0.12)))
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarPluginView()
        .environment(AppState())
}
