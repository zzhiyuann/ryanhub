import SwiftUI

// MARK: - Calendar Plugin View

/// Main calendar view showing upcoming events organized by day.
struct CalendarPluginView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = CalendarViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                syncHeader
                todaySection
                tomorrowSection
                thisWeekSection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .navigationTitle(L10n.toolkitCalendar)
        .navigationBarTitleDisplayMode(.large)
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
            }
        }
        .onAppear {
            if !viewModel.hasAnyEvents {
                viewModel.syncEvents()
            }
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
                    eventCard(event)
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
                    eventCard(event)
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
                ForEach(viewModel.weekEvents) { event in
                    eventCard(event)
                }
            }
        }
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
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .lineLimit(2)

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
        }
        .padding(HubLayout.cardInnerPadding)
        .frame(minHeight: 60)
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
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: tomorrow)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CalendarPluginView()
    }
}
