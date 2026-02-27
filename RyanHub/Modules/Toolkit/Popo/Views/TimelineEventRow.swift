import SwiftUI

// MARK: - Timeline Event Row

/// A unified row view for the POPO timeline that renders any timeline item type
/// (sensing event, narration, or nudge) with a distinct visual identity and
/// tap-to-expand detail behavior.
struct TimelineEventRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: TimelineItem
    let isExpanded: Bool
    let isLast: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Timeline column: icon + connecting line
                timelineColumn

                // Content column
                VStack(alignment: .leading, spacing: 6) {
                    // Header row: title + timestamp
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(itemTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                            Text(itemSubtitle)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                .lineLimit(isExpanded ? nil : 1)
                        }

                        Spacer()

                        Text(formattedTime)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    // Expanded detail section
                    if isExpanded {
                        expandedContent
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.bottom, 14)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timeline Column

    private var timelineColumn: some View {
        VStack(spacing: 0) {
            // Icon circle (nudges use Facai's actual avatar)
            if case .nudge = item {
                FacaiAvatar(size: 32)
            } else {
                ZStack {
                    Circle()
                        .fill(itemColor.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: itemIcon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(itemColor)
                }
            }

            // Connecting line (hidden for last item)
            if !isLast {
                Rectangle()
                    .fill(AdaptiveColors.border(for: colorScheme))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 32)
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        switch item {
        case .sensing(let event):
            sensingDetail(event)
        case .narration(let narration):
            narrationDetail(narration)
        case .nudge(let nudge):
            nudgeDetail(nudge)
        }
    }

    private func sensingDetail(_ event: SensingEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Payload key-value pairs
            ForEach(event.payload.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack(spacing: 8) {
                    Text(key.camelCaseToWords)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .frame(width: 80, alignment: .trailing)

                    Text(value)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
            }

            // Modality badge
            HStack(spacing: 4) {
                Image(systemName: itemIcon)
                    .font(.system(size: 10))
                Text(modalityDisplayName(event.modality))
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(itemColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(itemColor.opacity(0.1))
            )
        }
        .padding(.top, 4)
    }

    private func narrationDetail(_ narration: Narration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Full transcript
            Text(narration.transcript)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                // Duration badge
                detailBadge(
                    icon: "clock",
                    text: formatDuration(narration.duration),
                    color: Color.hubPrimaryLight
                )

                // Mood badge (if available)
                if let mood = narration.extractedMood {
                    detailBadge(
                        icon: "face.smiling",
                        text: mood,
                        color: Color.hubAccentYellow
                    )
                }
            }

            // Extracted events
            if let events = narration.extractedEvents, !events.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mentioned Events")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    FlowLayout(spacing: 6) {
                        ForEach(events, id: \.self) { event in
                            Text(event)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.hubPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(Color.hubPrimary.opacity(0.1))
                                )
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func nudgeDetail(_ nudge: Nudge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Full content
            Text(nudge.content)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                // Type badge
                detailBadge(
                    icon: nudgeTypeIcon(nudge.type),
                    text: nudge.type.rawValue.capitalized,
                    color: nudgeTypeColor(nudge.type)
                )

                // Acknowledged status
                if nudge.acknowledged {
                    detailBadge(
                        icon: "checkmark.circle.fill",
                        text: "Acknowledged",
                        color: Color.hubAccentGreen
                    )
                }
            }

            // Trigger
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                Text("Trigger: \(nudge.trigger)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Detail Badge

    private func detailBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(color.opacity(0.1))
        )
    }

    // MARK: - Item Properties

    private var itemTitle: String {
        switch item {
        case .sensing(let event):
            return modalityDisplayName(event.modality)
        case .narration:
            return "Voice Narration"
        case .nudge(let nudge):
            return "Facai says"
        }
    }

    private var itemSubtitle: String {
        switch item {
        case .sensing(let event):
            return sensingEventSummary(event)
        case .narration(let narration):
            return narration.transcript
        case .nudge(let nudge):
            return nudge.content
        }
    }

    private var itemIcon: String {
        switch item {
        case .sensing(let event):
            return modalityIcon(event.modality)
        case .narration:
            return "mic.fill"
        case .nudge:
            return "cat.fill"
        }
    }

    private var itemColor: Color {
        switch item {
        case .sensing(let event):
            return modalityColor(event.modality)
        case .narration:
            return Color.purple
        case .nudge:
            return Color.hubPrimary
        }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: item.timestamp)
    }

    // MARK: - Modality Helpers

    private func modalityIcon(_ modality: SensingModality) -> String {
        switch modality {
        case .motion: return "figure.walk"
        case .steps: return "shoeprints.fill"
        case .heartRate: return "heart.fill"
        case .hrv: return "waveform.path.ecg"
        case .sleep: return "moon.fill"
        case .location: return "mappin.and.ellipse"
        case .screen: return "iphone"
        case .workout: return "dumbbell.fill"
        case .activeEnergy: return "flame.fill"
        case .basalEnergy: return "flame"
        case .respiratoryRate: return "lungs.fill"
        case .bloodOxygen: return "drop.fill"
        case .noiseExposure: return "ear.fill"
        case .battery: return "battery.100"
        case .wifi: return "wifi"
        case .bluetooth: return "antenna.radiowaves.left.and.right"
        case .visit: return "building.2.fill"
        }
    }

    private func modalityColor(_ modality: SensingModality) -> Color {
        switch modality {
        case .motion: return Color(red: 0.2, green: 0.6, blue: 1.0)   // Blue
        case .steps: return Color(red: 0.2, green: 0.6, blue: 1.0)     // Blue
        case .heartRate: return Color.hubAccentRed
        case .hrv: return Color.hubAccentRed
        case .sleep: return Color.hubPrimaryLight
        case .location: return Color.hubAccentGreen
        case .screen: return AdaptiveColors.textSecondary(for: colorScheme)
        case .workout: return Color.hubAccentRed
        case .activeEnergy: return Color.hubAccentYellow
        case .basalEnergy: return Color.hubAccentYellow
        case .respiratoryRate: return Color(red: 0.4, green: 0.7, blue: 0.9)  // Light blue
        case .bloodOxygen: return Color(red: 0.3, green: 0.5, blue: 0.9)      // Blue
        case .noiseExposure: return Color(red: 0.8, green: 0.5, blue: 0.2)    // Orange
        case .battery: return Color.hubAccentGreen
        case .wifi: return Color.hubPrimaryLight
        case .bluetooth: return Color.hubPrimary
        case .visit: return Color.hubAccentGreen
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
        case .activeEnergy: return "Active Energy"
        case .basalEnergy: return "Resting Energy"
        case .respiratoryRate: return "Respiratory Rate"
        case .bloodOxygen: return "Blood Oxygen"
        case .noiseExposure: return "Noise Level"
        case .battery: return "Battery"
        case .wifi: return "Wi-Fi"
        case .bluetooth: return "Bluetooth"
        case .visit: return "Visit"
        }
    }

    private func sensingEventSummary(_ event: SensingEvent) -> String {
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
        case .activeEnergy:
            let kcal = event.payload["kcal"] ?? "0"
            return "\(kcal) kcal active"
        case .basalEnergy:
            let kcal = event.payload["kcal"] ?? "0"
            return "\(kcal) kcal resting"
        case .respiratoryRate:
            let rate = event.payload["breathsPerMin"] ?? "0"
            return "\(rate) breaths/min"
        case .bloodOxygen:
            let spo2 = event.payload["spo2"] ?? "0"
            return "\(spo2)% SpO2"
        case .noiseExposure:
            let db = event.payload["decibels"] ?? "0"
            return "\(db) dB"
        case .battery:
            let level = event.payload["level"] ?? "?"
            return "\(level)%"
        case .wifi:
            let ssid = event.payload["ssid"] ?? "unknown"
            return ssid
        case .bluetooth:
            let device = event.payload["device"] ?? "unknown"
            return device
        case .visit:
            let place = event.payload["description"] ?? "unknown"
            return place
        }
    }

    // MARK: - Nudge Helpers

    private func nudgeTypeIcon(_ type: NudgeType) -> String {
        switch type {
        case .insight: return "lightbulb.fill"
        case .reminder: return "bell.fill"
        case .encouragement: return "hand.thumbsup.fill"
        case .alert: return "exclamationmark.triangle.fill"
        }
    }

    private func nudgeTypeColor(_ type: NudgeType) -> Color {
        switch type {
        case .insight: return Color.hubAccentYellow
        case .reminder: return Color.hubPrimary
        case .encouragement: return Color.hubAccentGreen
        case .alert: return Color.hubAccentRed
        }
    }

    // MARK: - Formatting

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }
}

// MARK: - String Extension

extension String {
    /// Convert camelCase to human-readable words.
    var camelCaseToWords: String {
        unicodeScalars.reduce("") { result, scalar in
            if CharacterSet.uppercaseLetters.contains(scalar) {
                return result + " " + String(scalar)
            }
            return result + String(scalar)
        }
        .trimmingCharacters(in: .whitespaces)
        .capitalized
    }
}
