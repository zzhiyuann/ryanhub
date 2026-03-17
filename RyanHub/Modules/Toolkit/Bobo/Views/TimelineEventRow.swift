import SwiftUI
import AVKit
import Photos

// MARK: - Timeline Event Row

/// A unified row view for the BOBO timeline that renders any timeline item type
/// (sensing event, narration, or nudge) with a distinct visual identity and
/// tap-to-expand detail behavior.
struct TimelineEventRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: TimelineItem
    let isExpanded: Bool
    let isLast: Bool
    let onTap: () -> Void
    let onDelete: (() -> Void)?

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
        .contextMenu {
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Timeline Column

    private var timelineColumn: some View {
        VStack(spacing: 0) {
            // Icon circle (nudges use Bo's actual avatar)
            if case .nudge = item {
                BoAvatar(size: 32)
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
            // Audio events get a specialized expanded view
            if event.modality == .photo {
                photoDetail(event)
            } else if event.modality == .audio, event.payload["status"] == "transcript" {
                audioTranscriptDetail(event)
            } else if event.modality == .heartRate {
                heartRateDetail(event)
            } else if event.modality == .hrv {
                hrvDetail(event)
            } else if event.modality == .bloodOxygen {
                bloodOxygenDetail(event)
            } else if event.modality == .sleep {
                sleepDetail(event)
            } else if event.modality == .respiratoryRate {
                respiratoryRateDetail(event)
            } else {
                // Generic payload key-value pairs
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

    // MARK: - Heart Rate Detail (Aggregated + Anomaly)

    /// Expanded detail for heart rate events, showing aggregated stats or anomaly warning.
    private func heartRateDetail(_ event: SensingEvent) -> some View {
        let isAnomaly = event.payload["anomaly"] == "true"
        let bpm = event.payload["bpm"] ?? "0"

        return VStack(alignment: .leading, spacing: 8) {
            // Large BPM reading
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(bpm)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(isAnomaly ? Color.hubAccentRed : AdaptiveColors.textPrimary(for: colorScheme))

                Text("bpm")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            // Aggregated range (if available)
            if let minBPM = event.payload["min"], let maxBPM = event.payload["max"] {
                HStack(spacing: 8) {
                    detailBadge(
                        icon: "arrow.down",
                        text: "\(minBPM) bpm",
                        color: Color.hubAccentGreen
                    )
                    detailBadge(
                        icon: "arrow.up",
                        text: "\(maxBPM) bpm",
                        color: Color.hubAccentRed
                    )
                    if let count = event.payload["count"] {
                        detailBadge(
                            icon: "number",
                            text: "\(count) readings",
                            color: AdaptiveColors.textSecondary(for: colorScheme)
                        )
                    }
                }
            }

            // Anomaly warning
            if isAnomaly, let reason = event.payload["reason"] {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.hubAccentRed)

                    Text(heartRateAnomalyLabel(reason))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.hubAccentRed)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.hubAccentRed.opacity(0.1))
                )
            }

            // Source badge
            if let source = event.payload["source"] {
                detailBadge(
                    icon: "applewatch",
                    text: source,
                    color: AdaptiveColors.textSecondary(for: colorScheme)
                )
            }
        }
    }

    /// Convert anomaly reason codes to user-friendly labels.
    private func heartRateAnomalyLabel(_ reason: String) -> String {
        switch reason {
        case "tachycardia": return "High heart rate detected"
        case "bradycardia": return "Low heart rate detected"
        case "sudden_increase": return "Sudden heart rate increase"
        case "sudden_decrease": return "Sudden heart rate decrease"
        default: return "Abnormal heart rate"
        }
    }

    // MARK: - HRV Detail

    /// Expanded detail for HRV (Heart Rate Variability) events.
    private func hrvDetail(_ event: SensingEvent) -> some View {
        let sdnn = event.payload["sdnn"] ?? "0"

        return VStack(alignment: .leading, spacing: 8) {
            // Large SDNN reading
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(sdnn)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text("ms")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            // HRV context label
            HStack(spacing: 6) {
                Image(systemName: hrvStatusIcon(sdnn))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(hrvStatusColor(sdnn))

                Text(hrvStatusLabel(sdnn))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(hrvStatusColor(sdnn))
            }

            if let source = event.payload["source"] {
                detailBadge(
                    icon: "applewatch",
                    text: source,
                    color: AdaptiveColors.textSecondary(for: colorScheme)
                )
            }
        }
    }

    /// Contextual icon for HRV level.
    private func hrvStatusIcon(_ sdnnStr: String) -> String {
        guard let sdnn = Double(sdnnStr) else { return "questionmark.circle" }
        if sdnn >= 50 { return "checkmark.circle.fill" }
        if sdnn >= 20 { return "minus.circle" }
        return "exclamationmark.circle"
    }

    /// Contextual color for HRV level.
    private func hrvStatusColor(_ sdnnStr: String) -> Color {
        guard let sdnn = Double(sdnnStr) else { return AdaptiveColors.textSecondary(for: colorScheme) }
        if sdnn >= 50 { return Color.hubAccentGreen }
        if sdnn >= 20 { return Color.hubAccentYellow }
        return Color.hubAccentRed
    }

    /// Contextual label for HRV level.
    private func hrvStatusLabel(_ sdnnStr: String) -> String {
        guard let sdnn = Double(sdnnStr) else { return "Unknown" }
        if sdnn >= 50 { return "Good variability" }
        if sdnn >= 20 { return "Moderate variability" }
        return "Low variability"
    }

    // MARK: - Blood Oxygen Detail

    /// Expanded detail for blood oxygen (SpO2) events.
    private func bloodOxygenDetail(_ event: SensingEvent) -> some View {
        let spo2Str = event.payload["spo2"] ?? "0"
        let spo2 = Double(spo2Str) ?? 0
        let isLow = spo2 < 95

        return VStack(alignment: .leading, spacing: 8) {
            // Large SpO2 reading
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", spo2))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(isLow ? Color.hubAccentRed : AdaptiveColors.textPrimary(for: colorScheme))

                Text("%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            // Status indicator
            HStack(spacing: 6) {
                Image(systemName: isLow ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isLow ? Color.hubAccentRed : Color.hubAccentGreen)

                Text(isLow ? "Below normal range" : "Normal oxygen level")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isLow ? Color.hubAccentRed : Color.hubAccentGreen)
            }

            if let source = event.payload["source"] {
                detailBadge(
                    icon: "applewatch",
                    text: source,
                    color: AdaptiveColors.textSecondary(for: colorScheme)
                )
            }
        }
    }

    // MARK: - Sleep Detail

    /// Expanded detail for sleep analysis events.
    private func sleepDetail(_ event: SensingEvent) -> some View {
        let stage = event.payload["stage"] ?? "unknown"
        let formatter = ISO8601DateFormatter()

        return VStack(alignment: .leading, spacing: 8) {
            // Stage label with icon
            HStack(spacing: 8) {
                Image(systemName: sleepStageIcon(stage))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(sleepStageColor(stage))

                Text(sleepStageLabel(stage))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }

            // Duration (start — end)
            if let startStr = event.payload["startDate"],
               let endStr = event.payload["endDate"],
               let start = formatter.date(from: startStr),
               let end = formatter.date(from: endStr) {
                sleepDurationRow(start: start, end: end)
            }

            if let source = event.payload["source"] {
                detailBadge(
                    icon: "applewatch",
                    text: source,
                    color: AdaptiveColors.textSecondary(for: colorScheme)
                )
            }
        }
    }

    /// Helper to display sleep duration row (extracted to avoid `let` statements inside ViewBuilder).
    private func sleepDurationRow(start: Date, end: Date) -> some View {
        let duration = end.timeIntervalSince(start)
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return HStack(spacing: 8) {
            detailBadge(
                icon: "clock",
                text: formatDuration(duration),
                color: Color.hubPrimaryLight
            )
            detailBadge(
                icon: "arrow.right",
                text: "\(timeFormatter.string(from: start)) – \(timeFormatter.string(from: end))",
                color: AdaptiveColors.textSecondary(for: colorScheme)
            )
        }
    }

    /// Icon for sleep stage.
    private func sleepStageIcon(_ stage: String) -> String {
        switch stage {
        case "inBed": return "bed.double.fill"
        case "awake": return "sun.max.fill"
        case "asleep", "core": return "moon.fill"
        case "deep": return "moon.zzz.fill"
        case "rem": return "brain.head.profile"
        default: return "moon.fill"
        }
    }

    /// Color for sleep stage.
    private func sleepStageColor(_ stage: String) -> Color {
        switch stage {
        case "inBed": return AdaptiveColors.textSecondary(for: colorScheme)
        case "awake": return Color.hubAccentYellow
        case "asleep", "core": return Color.hubPrimaryLight
        case "deep": return Color.hubPrimary
        case "rem": return Color(red: 0.6, green: 0.4, blue: 0.9)
        default: return Color.hubPrimaryLight
        }
    }

    /// Display label for sleep stage.
    private func sleepStageLabel(_ stage: String) -> String {
        switch stage {
        case "inBed": return "In Bed"
        case "awake": return "Awake"
        case "asleep": return "Asleep"
        case "core": return "Core Sleep"
        case "deep": return "Deep Sleep"
        case "rem": return "REM Sleep"
        default: return "Sleep"
        }
    }

    // MARK: - Respiratory Rate Detail

    /// Expanded detail for respiratory rate events.
    private func respiratoryRateDetail(_ event: SensingEvent) -> some View {
        let rateStr = event.payload["breathsPerMin"] ?? "0"
        let rate = Double(rateStr) ?? 0

        return VStack(alignment: .leading, spacing: 8) {
            // Large reading
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", rate))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text("breaths/min")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            // Normal range indicator (12-20 is typical adult resting)
            let isNormal = rate >= 12 && rate <= 20
            HStack(spacing: 6) {
                Image(systemName: isNormal ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isNormal ? Color.hubAccentGreen : Color.hubAccentYellow)

                Text(isNormal ? "Normal range" : "Outside typical range (12-20)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isNormal ? Color.hubAccentGreen : Color.hubAccentYellow)
            }

            if let source = event.payload["source"] {
                detailBadge(
                    icon: "applewatch",
                    text: source,
                    color: AdaptiveColors.textSecondary(for: colorScheme)
                )
            }
        }
    }

    // MARK: - Photo / Video Detail

    /// Expanded detail for photo/video events.
    @ViewBuilder
    private func photoDetail(_ event: SensingEvent) -> some View {
        if event.payload["mediaType"] == "video", let assetId = event.payload["assetId"] {
            InlineVideoPlayer(assetIdentifier: assetId)
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if let fileId = event.payload["imageFileId"],
                  let image = BoboViewModel.loadPhoto(for: fileId) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Specialized expanded view for audio transcript events from WebSocket streaming.
    private func audioTranscriptDetail(_ event: SensingEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Full transcript text
            if let text = event.payload["text"], !text.isEmpty {
                Text(text)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Info badges row
            HStack(spacing: 8) {
                // Speaker badge (available after speaker_update enrichment)
                if let speaker = event.payload["speaker"], !speaker.isEmpty {
                    detailBadge(
                        icon: "person.fill",
                        text: speaker.capitalized,
                        color: Color.hubPrimary
                    )
                }

                // Timing info (start–end)
                if let startStr = event.payload["start"],
                   let endStr = event.payload["end"] {
                    detailBadge(
                        icon: "clock",
                        text: "\(startStr)s – \(endStr)s",
                        color: Color.hubPrimaryLight
                    )
                }

                // Speaker identification confidence
                if let confStr = event.payload["confidence"],
                   let conf = Double(confStr), conf > 0 {
                    detailBadge(
                        icon: "checkmark.seal",
                        text: String(format: "%.0f%%", conf * 100),
                        color: AdaptiveColors.textSecondary(for: colorScheme)
                    )
                }
            }
        }
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
            // Voice narrations have duration > 0 (audio was recorded);
            // text narrations have duration == 0.
            return narration.duration > 0 ? "Voice Narration" : "Text Narration"
        case .nudge:
            return "Bo says"
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
            if narration.transcript.isEmpty {
                // Show a fallback subtitle for narrations pending transcription
                if narration.duration > 0 {
                    let durationText = formatDuration(narration.duration) + " recorded"
                    if narration.audioFileRef != nil {
                        return "\(durationText) \u{00B7} Transcribing..."
                    } else {
                        return "\(durationText) \u{00B7} Uploading..."
                    }
                }
                return "Text entry"
            }
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
            // Heart rate anomaly gets a warning icon
            if event.modality == .heartRate, event.payload["anomaly"] == "true" {
                return "exclamationmark.heart.fill"
            }
            return modalityIcon(event.modality)
        case .narration(let narration):
            return narration.duration > 0 ? "mic.fill" : "text.bubble.fill"
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
            // Heart rate anomalies use red accent for the entire row
            if event.modality == .heartRate, event.payload["anomaly"] == "true" {
                return Color.hubAccentRed
            }
            // Blood oxygen below 95% highlights in red
            if event.modality == .bloodOxygen,
               let spo2 = Double(event.payload["spo2"] ?? "100"),
               spo2 < 95 {
                return Color.hubAccentRed
            }
            return modalityColor(event.modality)
        case .narration(let narration):
            return narration.duration > 0 ? Color.purple : Color.indigo
        case .nudge:
            return Color.hubPrimary
        case .meal:
            return Color.hubAccentYellow
        case .activity:
            return Color.hubAccentGreen
        }
    }

    /// Badge text shown alongside the timestamp for meal, activity, and health anomaly items.
    private var itemBadge: String? {
        switch item {
        case .sensing(let event):
            // Show anomaly badge for HR anomalies
            if event.modality == .heartRate, event.payload["anomaly"] == "true" {
                return "ANOMALY"
            }
            // Show low SpO2 badge
            if event.modality == .bloodOxygen,
               let spo2 = Double(event.payload["spo2"] ?? "100"),
               spo2 < 95 {
                return "LOW"
            }
            // Show aggregated count badge for HR
            if event.modality == .heartRate, let count = event.payload["count"] {
                return "\(count)x avg"
            }
            return nil
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

    /// Source tag from the sensing event's payload, if available.
    private var sensingSource: String? {
        if case .sensing(let event) = item {
            return event.payload["source"]
        }
        return nil
    }

    /// Media type from the sensing event's payload (photo/video).
    private var sensingMediaType: String? {
        if case .sensing(let event) = item {
            return event.payload["mediaType"]
        }
        return nil
    }

    /// Whether this timeline media item is likely captured by Ray-Ban Meta.
    /// Falls back to asset lookup for legacy events whose payload source was
    /// previously classified as "camera".
    private var isRBMetaSensingMedia: Bool {
        guard case .sensing(let event) = item, event.modality == .photo else {
            return false
        }
        return isRBMetaMediaEvent(event)
    }

    private func isRBMetaMediaEvent(_ event: SensingEvent) -> Bool {
        if event.payload["source"]?.hasPrefix("rb_meta") == true {
            return true
        }
        guard let assetId = event.payload["assetId"], !assetId.isEmpty else {
            return false
        }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetch.firstObject else {
            return false
        }
        return RBMetaMediaImporter.isRBMetaAsset(asset)
    }

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
        case .call: return "phone.fill"
        case .wifi: return "wifi"
        case .bluetooth: return "antenna.radiowaves.left.and.right"
        case .visit: return "building.2.fill"
        case .audio: return "waveform"
        case .photo:
            if sensingMediaType == "video" {
                return "video.fill"
            }
            if isRBMetaSensingMedia {
                return "eyeglasses"
            }
            return "camera.fill"
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
        case .call: return Color.green
        case .wifi: return Color.hubPrimaryLight
        case .bluetooth: return Color.hubPrimary
        case .visit: return Color.hubAccentGreen
        case .audio: return Color.hubAccentRed
        case .photo: return Color.hubPrimary
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
        case .call: return "Phone Call"
        case .wifi: return "Wi-Fi"
        case .bluetooth: return "Bluetooth"
        case .visit: return "Visit"
        case .audio: return "Audio"
        case .photo:
            let isVideo = sensingMediaType == "video"
            if isRBMetaSensingMedia {
                return isVideo ? "RB Meta Video" : "RB Meta Photo"
            }
            return isVideo ? "Video" : "Photo"
        }
    }

    private func sensingEventSummary(_ event: SensingEvent) -> String {
        switch event.modality {
        case .motion:
            let activity = (event.payload["activityType"] ?? "unknown").capitalized
            // Episode-based display: show duration and next activity when available
            if let durationStr = event.payload["duration"],
               let duration = Double(durationStr),
               let nextActivity = event.payload["nextActivity"] {
                let durationText = formatDuration(duration)
                return "\(activity) (\(durationText)) \u{2192} \(nextActivity.capitalized)"
            }
            // Ongoing episode (no duration yet)
            return "\(activity)"
        case .steps:
            let steps = event.payload["steps"] ?? "0"
            return "\(steps) steps"
        case .heartRate:
            let bpm = event.payload["bpm"] ?? "0"
            let isAnomaly = event.payload["anomaly"] == "true"
            // Aggregated event: show range
            if let minBPM = event.payload["min"], let maxBPM = event.payload["max"], minBPM != maxBPM {
                let prefix = isAnomaly ? "\u{26A0} " : ""
                return "\(prefix)\(bpm) BPM (\(minBPM)–\(maxBPM))"
            }
            // Anomaly single reading
            if isAnomaly {
                return "\u{26A0} \(bpm) BPM"
            }
            return "\(bpm) BPM"
        case .hrv:
            let sdnn = event.payload["sdnn"] ?? "0"
            return "\(sdnn) ms SDNN"
        case .sleep:
            let stage = event.payload["stage"] ?? "unknown"
            let stageLabel: String
            switch stage {
            case "inBed": stageLabel = "In Bed"
            case "awake": stageLabel = "Awake"
            case "asleep": stageLabel = "Asleep"
            case "core": stageLabel = "Core Sleep"
            case "deep": stageLabel = "Deep Sleep"
            case "rem": stageLabel = "REM Sleep"
            default: stageLabel = stage.capitalized
            }
            return stageLabel
        case .location:
            // 1. User-defined known place (Home, Work, Gym, etc.)
            if let label = event.payload["semanticLabel"], !label.isEmpty {
                if let placeName = event.payload["placeName"], !placeName.isEmpty {
                    return "\(label) \u{00B7} \(placeName)"
                }
                return label
            }
            // 2. Google Places POI name (e.g. "Starbucks", "Target")
            if let placeName = event.payload["placeName"], !placeName.isEmpty {
                let placeType = event.payload["placeType"] ?? ""
                if !placeType.isEmpty {
                    return "\(placeName) (\(placeType))"
                }
                return placeName
            }
            // 3. Address from Google Geocoding
            if let address = event.payload["address"], !address.isEmpty {
                let neighborhood = event.payload["neighborhood"] ?? ""
                if !neighborhood.isEmpty {
                    return "\(neighborhood) \u{00B7} \(address)"
                }
                return address
            }
            // 4. Fallback to coordinates
            let lat = event.payload["latitude"] ?? "?"
            let lon = event.payload["longitude"] ?? "?"
            if event.payload["visit"] == "true" {
                return "Visit at (\(lat), \(lon))"
            }
            return "(\(lat), \(lon))"
        case .screen:
            return screenEventSummary(event)
        case .workout:
            let type = event.payload["type"] ?? "unknown"
            let calories = event.payload["calories"] ?? "0"
            return "\(type) — \(calories) kcal"
        case .activeEnergy:
            let kcal = event.payload["kcal"] ?? "0"
            let hourLabel = event.payload["hourLabel"] ?? ""
            let ongoing = event.payload["ongoing"] == "true"
            if ongoing {
                return "\(kcal) kcal so far since \(hourLabel.components(separatedBy: "-").first ?? "")"
            }
            return "\(hourLabel): \(kcal) kcal"
        case .basalEnergy:
            let kcal = event.payload["kcal"] ?? "0"
            let hourLabel = event.payload["hourLabel"] ?? ""
            let ongoing = event.payload["ongoing"] == "true"
            if ongoing {
                return "\(kcal) kcal so far since \(hourLabel.components(separatedBy: "-").first ?? "")"
            }
            return "\(hourLabel): \(kcal) kcal"
        case .respiratoryRate:
            let rate = event.payload["breathsPerMin"] ?? "0"
            return "\(rate) breaths/min"
        case .bloodOxygen:
            let spo2 = event.payload["spo2"] ?? "0"
            let isLow = (Double(spo2) ?? 100) < 95
            return isLow ? "\u{26A0} \(spo2)% SpO2" : "\(spo2)% SpO2"
        case .noiseExposure:
            let db = event.payload["decibels"] ?? "0"
            return "\(db) dB"
        case .call:
            let direction = event.payload["direction"] ?? event.payload["state"] ?? "unknown"
            let status = event.payload["status"] ?? "unknown"
            let dirLabel = direction == "outgoing" ? "Outgoing" : "Incoming"

            if status == "answered" {
                if let durationStr = event.payload["duration"],
                   let duration = Double(durationStr) {
                    return "\(dirLabel) Call \u{00B7} \(formatDuration(duration))"
                }
                return "\(dirLabel) Call \u{00B7} ongoing"
            } else if status == "missed" {
                return "Missed Call"
            } else if status == "no_answer" {
                return "Outgoing Call \u{00B7} no answer"
            }
            // Legacy events fallback
            let state = event.payload["state"] ?? ""
            if state == "ended", event.payload["hasConnected"] == "true",
               let d = event.payload["duration"].flatMap(Double.init) {
                return "\(dirLabel) Call \u{00B7} \(formatDuration(d))"
            }
            return "\(dirLabel) Call"
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
        case .audio:
            let status = event.payload["status"] ?? ""
            switch status {
            case "listening":
                return "Listening..."
            case "transcript":
                let text = event.payload["text"] ?? ""
                let speaker = event.payload["speaker"]
                let preview = text.prefix(60)
                let suffix = text.count > 60 ? "..." : ""
                if let speaker, !speaker.isEmpty {
                    return "\(speaker.capitalized): \(preview)\(suffix)"
                }
                return String(preview) + suffix
            case "error":
                return event.payload["error"] ?? "Audio error"
            default:
                return "Audio Segment"
            }
        case .photo:
            let isVideo = event.payload["mediaType"] == "video"
            let isRBMeta = isRBMetaMediaEvent(event)
            if isVideo {
                let durStr = event.payload["duration"].map { " (\($0)s)" } ?? ""
                return isRBMeta ? "RB Meta Video\(durStr)" : "Video\(durStr)"
            }
            return isRBMeta ? "RB Meta Photo" : "Photo"
        }
    }

    // MARK: - Screen Event Helpers

    /// Build a rich summary for screen on events.
    /// Format: "Screen On · 5m 30s · Off for 15m"
    /// - The on-duration shows how long the screen was on (added retroactively when screen turns off)
    /// - The off-duration shows how long the screen was off before this unlock
    private func screenEventSummary(_ event: SensingEvent) -> String {
        let state = event.payload["state"] ?? "unknown"

        // Hourly aggregate — "Screen · 5 opens · 42m total"
        if state == "hourly_aggregate" {
            let count = event.payload["count"] ?? "0"
            let openLabel = count == "1" ? "open" : "opens"
            var parts = ["Screen \u{00B7} \(count) \(openLabel)"]
            if let totalDurStr = event.payload["totalDuration"],
               let totalDur = Double(totalDurStr), totalDur > 0 {
                parts.append("\(formatDuration(totalDur)) total")
            }
            return parts.joined(separator: " \u{00B7} ")
        }

        // Off events should be filtered from the timeline, but handle gracefully
        guard state == "on" else { return "Screen \(state)" }

        var parts: [String] = ["Screen On"]

        // On-duration (how long screen was on — enriched when screen turns off)
        if let onDurStr = event.payload["onDuration"],
           let onDur = Double(onDurStr), onDur > 0 {
            parts[0] = "Screen On \u{00B7} \(formatDuration(onDur))"
        }

        // Off-duration (how long screen was off before this unlock)
        if let offDurStr = event.payload["offDuration"],
           let offDur = Double(offDurStr), offDur > 0 {
            parts.append("Off for \(formatDuration(offDur))")
        }

        return parts.joined(separator: " \u{00B7} ")
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
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        if minutes > 0 {
            return secs > 0 ? "\(minutes)m \(secs)s" : "\(minutes)m"
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

// MARK: - Inline Video Player

/// Plays a video from the Photo Library inline in the timeline.
/// Shows thumbnail with play button; tapping loads and plays the video.
struct InlineVideoPlayer: View {
    let assetIdentifier: String
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if let thumbnail {
                // Thumbnail always rendered to provide intrinsic size
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .opacity(isPlaying ? 0 : 1)

                if let player, isPlaying {
                    VideoPlayer(player: player)
                } else {
                    Button {
                        loadAndPlay()
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 4)
                    }
                }
            } else {
                Color.black
                    .aspectRatio(16/9, contentMode: .fit)
                ProgressView().tint(.white)
                    .onAppear { loadThumbnail() }
            }
        }
    }

    private func loadThumbnail() {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject else { return }
        let size = CGSize(width: 800, height: 800)
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.resizeMode = .exact
        PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: opts) { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            guard !isDegraded else { return }
            Task { @MainActor in
                thumbnail = image
            }
        }
    }

    private func loadAndPlay() {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject else { return }
        let opts = PHVideoRequestOptions()
        opts.isNetworkAccessAllowed = true
        opts.deliveryMode = .automatic
        PHImageManager.default().requestPlayerItem(forVideo: asset, options: opts) { playerItem, _ in
            guard let playerItem else { return }
            Task { @MainActor in
                let avPlayer = AVPlayer(playerItem: playerItem)
                player = avPlayer
                isPlaying = true
                avPlayer.play()
            }
        }
    }
}
