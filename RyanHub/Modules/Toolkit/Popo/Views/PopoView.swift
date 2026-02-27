import SwiftUI

// MARK: - POPO View

/// The main view for the POPO (Proactive Personal Observer) toolkit plugin.
/// Displays Facai's insight card, current state dashboard, channel status,
/// chronological timeline, and narration recording controls.
struct PopoView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = PopoViewModel()
    @State private var showChannelDetail = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HubLayout.sectionSpacing) {
                // Section 1: Date Navigation
                DateNavigationBar(selectedDate: $viewModel.selectedDate)

                if viewModel.sensingEnabled {
                    // Section 2: Facai Insight Card (Hero)
                    facaiInsightCard

                    // Section 3: Current State Dashboard
                    currentStateDashboard

                    // Section 4: Channel Status Bar
                    channelStatusBar

                    // Section 5: Timeline
                    timelineSection

                    // Section 6: Record Narration
                    NarrationRecordButton(viewModel: viewModel)
                }

                // Sensing status footer (always visible)
                sensingStatusFooter
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Refresh health data from UserDefaults (may have been updated by Health module)
                viewModel.refreshHealthData()
                Task {
                    await viewModel.checkAndGenerateNudgesIfNeeded()
                }
            }
        }
    }

    // MARK: - Section 2: Facai Insight Card

    private var facaiInsightCard: some View {
        let todayNudges = viewModel.nudgesForSelectedDate

        return HubCard {
            if todayNudges.isEmpty {
                // No nudges — observing state
                facaiObservingState
            } else {
                // Show latest nudge as hero
                facaiNudgeContent(todayNudges)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .stroke(Color.hubPrimary.opacity(0.2), lineWidth: 1)
        )
    }

    private var facaiObservingState: some View {
        HStack(spacing: 14) {
            FacaiAvatar(size: 44)
                .overlay(
                    Circle()
                        .stroke(Color.hubPrimary.opacity(0.3), lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Facai")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                HStack(spacing: 6) {
                    PulsingObserveDot()

                    Text("Observing your day...")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }

            Spacer()

            if viewModel.isGeneratingNudges {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(Color.hubPrimary)
            }
        }
    }

    private func facaiNudgeContent(_ nudges: [Nudge]) -> some View {
        let latest = nudges[0]
        let remainingCount = nudges.count - 1

        return VStack(alignment: .leading, spacing: 12) {
            // Header: Avatar + name + type badge
            HStack(spacing: 12) {
                FacaiAvatar(size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Facai")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Text(formatTimestamp(latest.timestamp))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                Spacer()

                nudgeTypeBadge(latest.type)
            }

            // Speech bubble content
            Text(latest.content)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                )

            // "More insights" indicator
            if remainingCount > 0 {
                Button {
                    // Scroll to timeline where all nudges are shown
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis.bubble")
                            .font(.system(size: 12, weight: .medium))
                        Text("\(remainingCount) more insight\(remainingCount == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.hubPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func nudgeTypeBadge(_ type: NudgeType) -> some View {
        let (icon, color, label) = nudgeTypeInfo(type)
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(color.opacity(0.12))
        )
    }

    private func nudgeTypeInfo(_ type: NudgeType) -> (icon: String, color: Color, label: String) {
        switch type {
        case .insight: return ("lightbulb.fill", Color.hubAccentYellow, "Insight")
        case .reminder: return ("bell.fill", Color.hubPrimary, "Reminder")
        case .encouragement: return ("hand.thumbsup.fill", Color.hubAccentGreen, "Encouragement")
        case .alert: return ("exclamationmark.triangle.fill", Color.hubAccentRed, "Alert")
        }
    }

    // MARK: - Section 3: Current State Dashboard

    private var currentStateDashboard: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                statePill(
                    icon: "shoeprints.fill",
                    value: formatSteps(viewModel.daySummary.totalSteps),
                    label: "Steps",
                    color: Color(red: 0.2, green: 0.6, blue: 1.0)
                )

                statePill(
                    icon: "figure.walk",
                    value: viewModel.currentActivityType ?? "--",
                    label: "Activity",
                    color: Color.hubAccentGreen
                )

                statePill(
                    icon: "heart.fill",
                    value: viewModel.latestHeartRate.map { "\($0) bpm" } ?? "--",
                    label: "Heart Rate",
                    color: Color.hubAccentRed
                )

                statePill(
                    icon: "mappin",
                    value: viewModel.latestLocationLabel ?? "--",
                    label: "Location",
                    color: Color.hubAccentGreen
                )

                statePill(
                    icon: "battery.100",
                    value: viewModel.latestBatteryLevel.map { "\($0)%" } ?? "--",
                    label: "Battery",
                    color: Color.hubAccentGreen
                )

                // Health module stats: calories consumed
                if viewModel.daySummary.totalCaloriesConsumed > 0 {
                    statePill(
                        icon: "fork.knife",
                        value: "\(viewModel.daySummary.totalCaloriesConsumed)",
                        label: "Calories In",
                        color: Color.hubAccentYellow
                    )
                }

                // Health module stats: activity minutes
                if viewModel.daySummary.totalActivityMinutes > 0 {
                    statePill(
                        icon: "figure.run",
                        value: "\(viewModel.daySummary.totalActivityMinutes)m",
                        label: "Active",
                        color: Color.hubAccentGreen
                    )
                }

                // Health module stats: calories burned
                if viewModel.daySummary.totalCaloriesBurned > 0 {
                    statePill(
                        icon: "flame.fill",
                        value: "\(viewModel.daySummary.totalCaloriesBurned)",
                        label: "Burned",
                        color: Color.hubAccentRed
                    )
                }

                if let emoji = viewModel.latestMoodEmoji {
                    statePillEmoji(
                        emoji: emoji,
                        label: "Mood"
                    )
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func statePill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(width: 80, height: 72)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
        )
    }

    private func statePillEmoji(emoji: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 20))

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(width: 80, height: 72)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
        )
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            let k = Double(steps) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(steps)"
    }

    // MARK: - Section 4: Channel Status Bar

    private var channelStatusBar: some View {
        VStack(spacing: 8) {
            // Compact dot row
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showChannelDetail.toggle()
                }
            } label: {
                HStack(spacing: 0) {
                    Text("CHANNELS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach(viewModel.channelStatuses) { channel in
                            channelDot(for: channel)
                        }
                    }

                    Image(systemName: showChannelDetail ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .padding(.leading, 8)
                }
            }
            .buttonStyle(.plain)

            // Expanded detail view
            if showChannelDetail {
                channelDetailView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 4)
    }

    private func channelDot(for channel: PopoViewModel.ChannelStatus) -> some View {
        Circle()
            .fill(channelDotColor(channel.status))
            .frame(width: 8, height: 8)
    }

    private func channelDotColor(_ state: PopoViewModel.ChannelStatus.ChannelState) -> Color {
        switch state {
        case .active: return Color.hubAccentGreen
        case .stale: return Color.hubAccentYellow
        case .inactive: return AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3)
        }
    }

    private var channelDetailView: some View {
        VStack(spacing: 6) {
            ForEach(viewModel.channelStatuses) { channel in
                HStack(spacing: 8) {
                    Circle()
                        .fill(channelDotColor(channel.status))
                        .frame(width: 6, height: 6)

                    Image(systemName: channelIcon(channel.modality))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .frame(width: 16)

                    Text(channelDisplayName(channel.modality))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Spacer()

                    if let lastTime = channel.lastEventTime {
                        Text(formatRelativeTime(lastTime))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Text("\(channel.eventCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
        )
    }

    private func channelIcon(_ modality: SensingModality) -> String {
        switch modality {
        case .motion: return "figure.walk"
        case .steps: return "shoeprints.fill"
        case .heartRate: return "heart.fill"
        case .hrv: return "waveform.path.ecg"
        case .location: return "mappin.and.ellipse"
        case .screen: return "iphone"
        case .battery: return "battery.100"
        case .wifi: return "wifi"
        case .bluetooth: return "antenna.radiowaves.left.and.right"
        case .activeEnergy: return "flame.fill"
        case .sleep: return "moon.fill"
        default: return "sensor"
        }
    }

    private func channelDisplayName(_ modality: SensingModality) -> String {
        switch modality {
        case .motion: return "Motion"
        case .steps: return "Steps"
        case .heartRate: return "Heart Rate"
        case .hrv: return "HRV"
        case .location: return "Location"
        case .screen: return "Screen"
        case .battery: return "Battery"
        case .wifi: return "Wi-Fi"
        case .bluetooth: return "Bluetooth"
        case .activeEnergy: return "Active Energy"
        case .sleep: return "Sleep"
        default: return modality.rawValue.capitalized
        }
    }

    // MARK: - Section 5: Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            // Section header with event count badge
            HStack(spacing: 8) {
                SectionHeader(title: "TIMELINE")

                let itemCount = viewModel.timelineItems.count
                if itemCount > 0 {
                    Text("\(itemCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.hubPrimary)
                        )
                }

                Spacer()
            }

            let items = viewModel.timelineItems
            if items.isEmpty {
                emptyTimelineState
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        TimelineEventRow(
                            item: item,
                            isExpanded: viewModel.isExpanded(item.id),
                            isLast: index == items.count - 1
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.toggleExpanded(item.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var emptyTimelineState: some View {
        HubCard {
            VStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5))

                Text("No events yet")
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                Text("Events will appear here as sensors collect data")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Sensing Status Footer

    private var sensingStatusFooter: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            // Sensing toggle
            HubCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(viewModel.sensingEnabled ? Color.hubAccentGreen : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3))
                                .frame(width: 8, height: 8)

                            Text("Sensing Engine")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        }

                        Text(viewModel.sensingEnabled ? "Actively observing" : "Paused")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    Toggle("", isOn: $viewModel.sensingEnabled)
                        .labelsHidden()
                        .tint(Color.hubPrimary)
                }
            }

            // Auto-sync status row (only when sensing is on)
            if viewModel.sensingEnabled {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        if viewModel.isSyncing {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                            Text("Syncing...")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        } else if viewModel.lastSyncError != nil {
                            Image(systemName: "exclamationmark.icloud.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.hubAccentRed)
                            Text("Sync error")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.hubAccentRed)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            Text(viewModel.autoSyncStatusText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }

                    Spacer()

                    Button {
                        Task { await viewModel.syncNow() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSyncing)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Formatting Helpers

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Pulsing Observe Dot

/// A subtle pulsing dot that indicates Facai is actively observing.
private struct PulsingObserveDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.hubPrimary)
            .frame(width: 6, height: 6)
            .opacity(isPulsing ? 0.3 : 1.0)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Preview

#Preview {
    PopoView()
}
