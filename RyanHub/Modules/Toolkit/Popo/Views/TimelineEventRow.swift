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
                    // Header row: title + badge + timestamp
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

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(formattedTime)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                            if let badge = itemBadge {
                                Text(badge)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(itemColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(itemColor.opacity(0.12))
                                    )
                            }
                        }
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
        case .meal(let food):
            mealDetail(food)
        case .activity(let activity):
            activityDetail(activity)
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
                // Duration badge (only for audio narrations with recorded duration)
                if narration.duration > 0 {
                    detailBadge(
                        icon: "clock",
                        text: formatDuration(narration.duration),
                        color: Color.hubPrimaryLight
                    )
                }

                // Mood badge (if available)
                if let mood = narration.extractedMood {
                    detailBadge(
                        icon: "face.smiling",
                        text: mood,
                        color: Color.hubAccentYellow
                    )
                }
            }

            // Affect Analysis Results
            if let affect = narration.affectAnalysis {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Emotion Analysis")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    // Brief summary
                    if let summary = affect.briefSummary {
                        Text(summary)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            .italic()
                    }

                    // Emotion badges row
                    HStack(spacing: 8) {
                        if let primary = affect.primaryEmotion {
                            detailBadge(
                                icon: "brain.head.profile",
                                text: primary.capitalized,
                                color: Color.hubPrimary
                            )
                        }
                        if let secondary = affect.secondaryEmotion {
                            detailBadge(
                                icon: "sparkles",
                                text: secondary.capitalized,
                                color: Color.hubPrimaryLight
                            )
                        }
                    }

                    // Metrics row
                    HStack(spacing: 8) {
                        if let valence = affect.valence {
                            detailBadge(
                                icon: valence >= 0 ? "arrow.up.circle" : "arrow.down.circle",
                                text: String(format: "Valence: %.1f", valence),
                                color: valence >= 0 ? Color.hubAccentGreen : Color.hubAccentRed
                            )
                        }
                        if let arousal = affect.arousal {
                            detailBadge(
                                icon: "bolt.fill",
                                text: String(format: "Arousal: %.1f", arousal),
                                color: Color.hubAccentYellow
                            )
                        }
                    }

                    // Mood/Energy/Stress scores
                    HStack(spacing: 8) {
                        if let mood = affect.mood {
                            detailBadge(icon: "face.smiling", text: "Mood: \(mood)/10", color: Color.hubAccentGreen)
                        }
                        if let energy = affect.energy {
                            detailBadge(icon: "bolt.heart", text: "Energy: \(energy)/10", color: Color.hubAccentYellow)
                        }
                        if let stress = affect.stress {
                            detailBadge(icon: "waveform.path.ecg", text: "Stress: \(stress)/10", color: Color.hubAccentRed)
                        }
                    }

                    // Confidence
                    if let confidence = affect.confidence {
                        detailBadge(
                            icon: "checkmark.seal",
                            text: String(format: "Confidence: %.0f%%", confidence * 100),
                            color: AdaptiveColors.textSecondary(for: colorScheme)
                        )
                    }
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

    private func mealDetail(_ food: FoodEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // AI summary or description
            if let summary = food.aiSummary, !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Individual food items
            if let items = food.items, !items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(items) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.hubAccentYellow.opacity(0.5))
                                .frame(width: 5, height: 5)

                            Text(item.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                            Spacer()

                            if item.calories > 0 {
                                Text("\(item.calories) cal")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                        }
                    }
                }
            }

            // Macros badges
            HStack(spacing: 8) {
                if let cal = food.calories, cal > 0 {
                    detailBadge(icon: "flame.fill", text: "\(cal) cal", color: Color.hubAccentYellow)
                }
                if let protein = food.protein, protein > 0 {
                    detailBadge(icon: "p.circle.fill", text: "\(protein)g P", color: Color.hubAccentGreen)
                }
                if let carbs = food.carbs, carbs > 0 {
                    detailBadge(icon: "c.circle.fill", text: "\(carbs)g C", color: Color(red: 0.2, green: 0.6, blue: 1.0))
                }
                if let fat = food.fat, fat > 0 {
                    detailBadge(icon: "f.circle.fill", text: "\(fat)g F", color: Color.hubAccentRed)
                }
            }
        }
        .padding(.top, 4)
    }

    private func activityDetail(_ activity: ActivityEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // AI summary or note
            if let summary = activity.aiSummary, !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            } else if let note = activity.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Individual exercises
            if !activity.exercises.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(activity.exercises) { exercise in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.hubAccentGreen.opacity(0.5))
                                .frame(width: 5, height: 5)

                            Text(exercise.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                            Spacer()

                            // Sets x reps @ weight for strength exercises
                            if let sets = exercise.sets, let reps = exercise.reps {
                                HStack(spacing: 2) {
                                    Text("\(sets)x\(reps)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                                    if let weight = exercise.weight {
                                        Text("@ \(weight)")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                    }
                                }
                            }
                            // Duration for cardio exercises
                            else if let duration = exercise.duration {
                                Text("\(duration) min")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                        }
                    }
                }
            }

            // Summary badges
            HStack(spacing: 8) {
                detailBadge(
                    icon: "clock",
                    text: activity.formattedDuration,
                    color: Color.hubAccentGreen
                )
                if let cal = activity.caloriesBurned, cal > 0 {
                    detailBadge(
                        icon: "flame.fill",
                        text: "\(cal) cal burned",
                        color: Color.hubAccentYellow
                    )
                }
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
        case .narration(let narration):
            return narration.audioFileRef != nil ? "Voice Narration" : "Text Narration"
        case .nudge:
            return "Facai says"
        case .meal(let food):
            return food.mealType.displayName
        case .activity(let activity):
            return activity.type
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
        case .meal(let food):
            return food.aiSummary ?? food.displayName
        case .activity(let activity):
            var parts: [String] = []
            parts.append(activity.formattedDuration)
            if let cal = activity.caloriesBurned, cal > 0 {
                parts.append("\(cal) cal burned")
            }
            return parts.joined(separator: " \u{00B7} ")
        }
    }

    private var itemIcon: String {
        switch item {
        case .sensing(let event):
            return modalityIcon(event.modality)
        case .narration(let narration):
            return narration.audioFileRef != nil ? "mic.fill" : "text.bubble.fill"
        case .nudge:
            return "cat.fill"
        case .meal:
            return "fork.knife"
        case .activity(let activity):
            return ActivityParser.icon(for: activity.type)
        }
    }

    private var itemColor: Color {
        switch item {
        case .sensing(let event):
            return modalityColor(event.modality)
        case .narration(let narration):
            return narration.audioFileRef != nil ? Color.purple : Color.indigo
        case .nudge:
            return Color.hubPrimary
        case .meal:
            return Color.hubAccentYellow
        case .activity:
            return Color.hubAccentGreen
        }
    }

    /// Badge text shown alongside the timestamp for meal and activity items.
    private var itemBadge: String? {
        switch item {
        case .meal(let food):
            if let cal = food.calories, cal > 0 {
                return "\(cal) cal"
            }
            return nil
        case .activity(let activity):
            return activity.formattedDuration
        default:
            return nil
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
            let activity = (event.payload["activityType"] ?? "unknown").capitalized
            let confidence = event.payload["confidence"] ?? ""
            // Show transition info if available (HAR clustering output)
            if let previousActivity = event.payload["previousActivity"],
               let durationStr = event.payload["previousDuration"],
               let duration = Double(durationStr) {
                let minutes = Int(duration) / 60
                let durationText = minutes > 0 ? "\(minutes)m" : "\(Int(duration))s"
                return "\(previousActivity.capitalized) \u{2192} \(activity) \u{00B7} was \(previousActivity) for \(durationText)"
            }
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
            // Prefer semantic label and address from enrichment
            if let label = event.payload["semanticLabel"], !label.isEmpty {
                let address = event.payload["address"] ?? ""
                if !address.isEmpty {
                    return "\(label) \u{00B7} \(address)"
                }
                return label
            }
            // Fallback to coordinates
            let lat = event.payload["latitude"] ?? "?"
            let lon = event.payload["longitude"] ?? "?"
            if event.payload["visit"] == "true" {
                return "Visit at (\(lat), \(lon))"
            }
            return "(\(lat), \(lon))"
        case .screen:
            let state = event.payload["state"] ?? "unknown"
            return state == "on" ? "Screen on" : state == "off" ? "Screen off" : state
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
            // Aggregated scan: show device counts
            if let totalStr = event.payload["deviceCount"],
               let namedStr = event.payload["namedCount"] {
                return "\(totalStr) devices nearby (\(namedStr) named)"
            }
            // Legacy single-device events (backwards compatibility)
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
