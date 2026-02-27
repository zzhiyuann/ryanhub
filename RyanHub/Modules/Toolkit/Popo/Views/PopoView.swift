import SwiftUI

// MARK: - POPO View

/// The main view for the POPO (Proactive Personal Observer) toolkit plugin.
/// Displays sensing status, modality summary, and recent events.
struct PopoView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = PopoViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HubLayout.sectionSpacing) {
                // Header
                header

                // Sensing toggle card
                sensingToggleCard

                // Status card (only when sensing is active)
                if viewModel.sensingEnabled {
                    statusCard
                    modalitySummarySection
                    recentEventsSection
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("POPO")
                .font(.hubTitle)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text("Proactive Personal Observer")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .padding(.top, 8)
    }

    // MARK: - Sensing Toggle

    private var sensingToggleCard: some View {
        HubCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(
                                viewModel.sensingEnabled
                                    ? Color.hubAccentGreen
                                    : AdaptiveColors.textSecondary(for: colorScheme)
                            )

                        Text("Sensing Engine")
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    }

                    Text(viewModel.sensingEnabled ? "Actively observing behavioral signals" : "Tap to start background sensing")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                Spacer()

                Toggle("", isOn: $viewModel.sensingEnabled)
                    .labelsHidden()
                    .tint(Color.hubPrimary)
            }
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                HStack {
                    statusItem(
                        title: "Events",
                        value: "\(viewModel.engine.recentEvents.count)",
                        icon: "chart.bar.fill",
                        color: Color.hubPrimary
                    )

                    Spacer()

                    statusItem(
                        title: "Pending",
                        value: "\(viewModel.engine.pendingEventCount)",
                        icon: "arrow.triangle.2.circlepath",
                        color: Color.hubAccentYellow
                    )

                    Spacer()

                    statusItem(
                        title: "Last Sync",
                        value: viewModel.lastSyncTimeString ?? "Never",
                        icon: "icloud.and.arrow.up.fill",
                        color: Color.hubAccentGreen
                    )
                }

                // Sync button
                if viewModel.engine.pendingEventCount > 0 {
                    Button {
                        Task { await viewModel.syncNow() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13, weight: .medium))
                            Text("Sync Now")
                                .font(.hubCaption)
                        }
                        .foregroundStyle(Color.hubPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                                .stroke(Color.hubPrimary, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func statusItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Modality Summary

    private var modalitySummarySection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "ACTIVE SENSORS")

            let summary = viewModel.engine.modalitySummary
            if summary.isEmpty {
                HubCard {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Text("Waiting for sensor data...")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: HubLayout.itemSpacing),
                    GridItem(.flexible(), spacing: HubLayout.itemSpacing)
                ], spacing: HubLayout.itemSpacing) {
                    ForEach(summary, id: \.modality) { item in
                        modalityCard(item)
                    }
                }
            }
        }
    }

    private func modalityCard(_ item: (modality: SensingModality, count: Int, latest: Date?)) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: modalityIcon(item.modality))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(modalityColor(item.modality))

                    Text(modalityDisplayName(item.modality))
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Spacer()

                    Text("\(item.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(modalityColor(item.modality))
                }

                if let latest = item.latest {
                    Text(timeAgoString(from: latest))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }
        }
    }

    // MARK: - Recent Events

    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "RECENT EVENTS")

            // Modality filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip(title: "All", modality: nil)
                    ForEach(SensingModality.allCases, id: \.self) { modality in
                        filterChip(title: modalityDisplayName(modality), modality: modality)
                    }
                }
            }

            let events = Array(viewModel.filteredEvents.prefix(20))
            if events.isEmpty {
                HubCard {
                    Text("No events yet")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                ForEach(events) { event in
                    eventRow(event)
                }
            }
        }
    }

    private func filterChip(title: String, modality: SensingModality?) -> some View {
        let isSelected = viewModel.selectedModality == modality
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedModality = modality
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(
                    isSelected
                        ? Color.white
                        : AdaptiveColors.textSecondary(for: colorScheme)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.hubPrimary : AdaptiveColors.surfaceSecondary(for: colorScheme))
                )
        }
        .buttonStyle(.plain)
    }

    private func eventRow(_ event: SensingEvent) -> some View {
        HubCard {
            HStack(spacing: 10) {
                // Modality icon
                Image(systemName: modalityIcon(event.modality))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(modalityColor(event.modality))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(modalityColor(event.modality).opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(modalityDisplayName(event.modality))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Text(eventSummary(event))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .lineLimit(1)
                }

                Spacer()

                Text(timeAgoString(from: event.timestamp))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
        }
    }

    // MARK: - Helpers

    private func modalityIcon(_ modality: SensingModality) -> String {
        switch modality {
        case .motion: return "figure.walk"
        case .steps: return "shoeprints.fill"
        case .heartRate: return "heart.fill"
        case .hrv: return "waveform.path.ecg"
        case .sleep: return "moon.fill"
        case .location: return "location.fill"
        case .screen: return "iphone"
        case .workout: return "dumbbell.fill"
        }
    }

    private func modalityColor(_ modality: SensingModality) -> Color {
        switch modality {
        case .motion: return Color.hubAccentGreen
        case .steps: return Color.hubPrimary
        case .heartRate: return Color.hubAccentRed
        case .hrv: return Color.hubAccentYellow
        case .sleep: return Color.hubPrimaryLight
        case .location: return Color.hubAccentGreen
        case .screen: return Color.hubPrimary
        case .workout: return Color.hubAccentRed
        }
    }

    private func modalityDisplayName(_ modality: SensingModality) -> String {
        switch modality {
        case .motion: return "Motion"
        case .steps: return "Steps"
        case .heartRate: return "Heart Rate"
        case .hrv: return "HRV"
        case .sleep: return "Sleep"
        case .location: return "Location"
        case .screen: return "Screen"
        case .workout: return "Workout"
        }
    }

    private func eventSummary(_ event: SensingEvent) -> String {
        switch event.modality {
        case .motion:
            let activity = event.payload["activityType"] ?? "unknown"
            let confidence = event.payload["confidence"] ?? ""
            return "\(activity) (\(confidence))"
        case .steps:
            let steps = event.payload["steps"] ?? "0"
            return "\(steps) steps"
        case .heartRate:
            let bpm = event.payload["bpm"] ?? "0"
            return "\(bpm) BPM"
        case .hrv:
            let sdnn = event.payload["sdnn"] ?? "0"
            return "\(sdnn) ms SDNN"
        case .sleep:
            let stage = event.payload["stage"] ?? "unknown"
            return "Stage: \(stage)"
        case .location:
            let lat = event.payload["latitude"] ?? "?"
            let lon = event.payload["longitude"] ?? "?"
            return "(\(lat), \(lon))"
        case .screen:
            let state = event.payload["state"] ?? "unknown"
            let duration = event.payload["sessionDuration"] ?? "0"
            return "\(state) — \(duration)s"
        case .workout:
            let type = event.payload["type"] ?? "unknown"
            let calories = event.payload["calories"] ?? "0"
            return "\(type) — \(calories) kcal"
        }
    }

    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Preview

#Preview {
    PopoView()
}
