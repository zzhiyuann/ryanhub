import SwiftUI

// MARK: - POPO View

/// The main view for the POPO (Proactive Personal Observer) toolkit plugin.
/// The Facai card serves as the central control hub: sensing toggle, nudge display,
/// text diary input, and voice recording are all consolidated here.
struct PopoView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = PopoViewModel()
    @State private var showChannelDetail = false
    @State private var isPressingMic = false
    @FocusState private var isTextDiaryFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HubLayout.sectionSpacing) {
                // Section 1: Date Navigation
                DateNavigationBar(selectedDate: $viewModel.selectedDate)

                // Section 2: Facai Control Hub Card (always visible)
                facaiInsightCard

                if viewModel.sensingEnabled {
                    // Section 3: Current State Dashboard
                    currentStateDashboard

                    // Section 4: Channel Status Bar
                    channelStatusBar

                    // Section 5: Timeline
                    timelineSection
                }

                // Auto-sync status (only when sensing is on)
                if viewModel.sensingEnabled {
                    autoSyncStatusRow
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshHealthData()
                Task {
                    await viewModel.checkAndGenerateNudgesIfNeeded()
                }
            }
        }
    }

    // MARK: - Section 2: Facai Insight Card (Central Hub)

    private var facaiInsightCard: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 14) {
                // Row 1: Avatar + Name + Sensing Toggle
                facaiCardHeader

                // Row 2: Nudge content or status message
                facaiCardBody

                // Row 3: Diary input (text field + mic icon, transforms during recording)
                diaryInputRow
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .stroke(Color.hubPrimary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Facai Card Header (Avatar + Name + Toggle)

    private var facaiCardHeader: some View {
        HStack(spacing: 12) {
            FacaiAvatar(size: 40)
                .overlay(
                    Circle()
                        .stroke(
                            viewModel.sensingEnabled
                                ? Color.hubPrimary.opacity(0.3)
                                : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.2),
                            lineWidth: 2
                        )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Facai")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.sensingEnabled ? Color.hubAccentGreen : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3))
                        .frame(width: 6, height: 6)

                    Text(viewModel.sensingEnabled ? "Sensing on" : "Sensing off")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }

            Spacer()

            if viewModel.isGeneratingNudges {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(Color.hubPrimary)
            }

            Toggle("", isOn: $viewModel.sensingEnabled)
                .labelsHidden()
                .tint(Color.hubPrimary)
        }
    }

    // MARK: - Facai Card Body (Nudge or Status)

    private var facaiCardBody: some View {
        Group {
            if !viewModel.sensingEnabled {
                // Sensing is off — paused state
                HStack(spacing: 8) {
                    Image(systemName: "pause.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    Text("Sensing paused")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
                .padding(.vertical, 4)
            } else {
                let todayNudges = viewModel.nudgesForSelectedDate
                if !todayNudges.isEmpty {
                    // Show latest nudge
                    facaiNudgeContent(todayNudges)
                }
            }
        }
    }

    private func facaiNudgeContent(_ nudges: [Nudge]) -> some View {
        let latest = nudges[0]
        let remainingCount = nudges.count - 1

        return VStack(alignment: .leading, spacing: 8) {
            // Type badge + timestamp row
            HStack(spacing: 8) {
                nudgeTypeBadge(latest.type)

                Text(formatTimestamp(latest.timestamp))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                Spacer()
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

    // MARK: - Diary Input Row (Text + Mic)

    /// Unified diary input row: text field on the left, mic icon on the right.
    /// During recording, the text area transforms into a recording indicator.
    /// During upload/error, shows the corresponding state inline.
    private var diaryInputRow: some View {
        Group {
            switch viewModel.narrationState {
            case .idle, .done:
                idleDiaryRow
            case .recording:
                recordingDiaryRow
            case .uploading:
                uploadingDiaryRow
            case .error(let message):
                errorDiaryRow(message)
            }
        }
    }

    // MARK: Idle State — Text Field + Mic Icon

    private var idleDiaryRow: some View {
        HStack(spacing: 8) {
            // Text input area
            Image(systemName: "square.and.pencil")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            TextField("What's on your mind...", text: $viewModel.textDiaryInput)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .focused($isTextDiaryFocused)
                .onSubmit {
                    submitTextDiary()
                }
                .disabled(viewModel.isSubmittingTextDiary)

            if viewModel.isSubmittingTextDiary {
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(Color.hubPrimary)
            } else if !viewModel.textDiaryInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    submitTextDiary()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.hubPrimary)
                }
                .buttonStyle(.plain)
            }

            // Mic icon — long-press to record
            micButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
        )
    }

    /// Compact mic icon with long-press gesture to start/stop recording.
    private var micButton: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color.hubPrimary)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(Color.hubPrimary.opacity(0.12))
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressingMic else { return }
                        isPressingMic = true
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        viewModel.startNarration()
                    }
                    .onEnded { _ in
                        isPressingMic = false
                        viewModel.stopNarration()
                    }
            )
    }

    private func submitTextDiary() {
        let text = viewModel.textDiaryInput
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isTextDiaryFocused = false
        viewModel.addTextDiary(text)
    }

    // MARK: Recording State — Red Pulsing Mic + Duration

    private var recordingDiaryRow: some View {
        HStack(spacing: 10) {
            // Recording indicator
            InlinePulsingDot()

            Text("Recording...")
                .font(.hubCaption)
                .foregroundStyle(Color.hubAccentRed)

            Text(formatDuration(viewModel.narrationDuration))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Spacer()

            // Cancel button
            Button {
                isPressingMic = false
                viewModel.cancelNarration()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
            .buttonStyle(.plain)

            // Stop / recording mic icon (pulsing red)
            recordingMicButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.hubAccentRed.opacity(0.08))
        )
    }

    /// Pulsing red mic icon shown during recording. Tap or release to stop.
    private var recordingMicButton: some View {
        PulsingRecordingMic()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        isPressingMic = false
                        viewModel.stopNarration()
                    }
            )
    }

    // MARK: Uploading State

    private var uploadingDiaryRow: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(Color.hubPrimary)

            Text("Uploading & analyzing...")
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Spacer()

            Text(formatDuration(viewModel.narrationDuration))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
        )
    }

    // MARK: Error State

    private func errorDiaryRow(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.hubAccentYellow)

            Text(message)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                .lineLimit(1)

            Spacer()

            Button {
                viewModel.cancelNarration()
            } label: {
                Text("Dismiss")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.hubPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
        )
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

    // MARK: - Auto-Sync Status Row

    private var autoSyncStatusRow: some View {
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

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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

// MARK: - Inline Pulsing Dot (Recording Indicator)

/// A small red circle that pulses to indicate active recording, used inline in the Facai card.
private struct InlinePulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.hubAccentRed)
            .frame(width: 8, height: 8)
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Pulsing Recording Mic Icon

/// A mic icon that pulses red during active voice recording.
private struct PulsingRecordingMic: View {
    @State private var isPulsing = false

    var body: some View {
        Image(systemName: "stop.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(Color.hubAccentRed)
                    .opacity(isPulsing ? 0.7 : 1.0)
            )
            .animation(
                .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
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
