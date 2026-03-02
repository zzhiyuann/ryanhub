import Foundation
import AVFoundation
import HealthKit
import UIKit
import UserNotifications

// MARK: - Narration Recording State

/// Represents the current state of the narration recording flow.
enum NarrationRecordingState: Equatable {
    case idle
    case recording
    case uploading
    case done
    case error(String)
}

// MARK: - Timeline Item

/// A unified timeline item that wraps any type of BOBO event for chronological display.
/// Enables rendering sensing events, narrations, nudges, meals, and activities in a single timeline.
enum TimelineItem: Identifiable {
    case sensing(SensingEvent)
    case narration(Narration)
    case nudge(Nudge)
    case meal(FoodEntry)
    case activity(ActivityEntry)

    var id: UUID {
        switch self {
        case .sensing(let event): return event.id
        case .narration(let narration): return narration.id
        case .nudge(let nudge): return nudge.id
        case .meal(let food): return food.id
        case .activity(let activity): return activity.id
        }
    }

    var timestamp: Date {
        switch self {
        case .sensing(let event): return event.timestamp
        case .narration(let narration): return narration.timestamp
        case .nudge(let nudge): return nudge.timestamp
        case .meal(let food): return food.date
        case .activity(let activity): return activity.date
        }
    }
}

// MARK: - Today Summary

/// Aggregated statistics for the overview card.
struct DayOverviewSummary {
    var totalSteps: Int = 0
    var activityBreakdown: [String: Int] = [:]  // activity type -> count
    var locationChanges: Int = 0
    var screenEvents: Int = 0
    var narrationCount: Int = 0
    var nudgeCount: Int = 0
    var eventCount: Int = 0
    var totalCaloriesConsumed: Int = 0
    var totalActivityMinutes: Int = 0
    var totalCaloriesBurned: Int = 0
}

// MARK: - BOBO View Model

/// Main view model for the BOBO (Proactive Personal Observer) sensing module.
/// Coordinates the sensing engine and exposes observable state for the UI.
@MainActor
@Observable
final class BoboViewModel {
    // MARK: - State

    /// The sensing engine that manages all sensors (shared singleton for BGTask access).
    let engine = SensingEngine.shared

    /// Whether sensing has been toggled on by the user.
    var sensingEnabled: Bool = false {
        didSet {
            if sensingEnabled {
                engine.startSensing()
                startNudgeTimer()
                startHealthKitRefreshTimer()
            } else {
                engine.stopSensing()
                stopNudgeTimer()
                stopHealthKitRefreshTimer()
            }
            // Persist the preference
            UserDefaults.standard.set(sensingEnabled, forKey: StorageKeys.sensingEnabled)
        }
    }

    /// Whether the always-on audio stream sensor is enabled.
    /// Independent from main sensing toggle due to battery and privacy concerns.
    var audioStreamEnabled: Bool = false {
        didSet {
            if audioStreamEnabled {
                engine.startAudioStream()
            } else {
                engine.stopAudioStream()
            }
        }
    }

    /// The currently selected modality filter for the event list (nil = all).
    var selectedModality: SensingModality?

    /// The currently selected date for day navigation.
    var selectedDate: Date = Date()

    /// Set of expanded timeline item IDs (for tap-to-expand behavior).
    var expandedItemIDs: Set<UUID> = []

    /// Narrations loaded from local storage.
    var narrations: [Narration] = []

    /// Nudges loaded from local storage.
    var nudges: [Nudge] = []

    /// Food entries loaded from Health module's UserDefaults storage.
    var foodEntries: [FoodEntry] = []

    /// Activity entries loaded from Health module's UserDefaults storage.
    var activityEntries: [ActivityEntry] = []

    /// HealthKit events fetched directly from Apple Health for the selected date.
    /// This bypasses the HealthSensor pipeline — HealthKit IS the source of truth.
    var healthKitEvents: [SensingEvent] = []

    // MARK: - Text Diary State

    /// Text bound to the diary text input field.
    var textDiaryInput: String = ""

    /// Whether a text diary submission is in progress.
    private(set) var isSubmittingTextDiary: Bool = false

    // MARK: - Narration Recording State

    /// Current state of the recording flow.
    private(set) var narrationState: NarrationRecordingState = .idle

    /// Duration of the current or last recording, in seconds.
    private(set) var narrationDuration: TimeInterval = 0

    /// Audio power levels for waveform visualization (0–1 normalized).
    private(set) var narrationAudioLevels: [CGFloat] = []

    /// Whether a narration is currently being recorded.
    var isRecordingNarration: Bool {
        narrationState == .recording
    }

    // MARK: - Nudge Generation State

    /// Whether nudge generation is currently in progress.
    private(set) var isGeneratingNudges: Bool = false

    /// Timer that triggers periodic nudge generation (every 2 hours).
    private var nudgeTimer: Timer?

    /// Interval between nudge generation runs (2 hours).
    private static let nudgeInterval: TimeInterval = 7200

    /// Timer that re-queries HealthKit while the app is in the foreground.
    private var healthKitRefreshTimer: Timer?

    // MARK: - Private Recording Properties

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

    // MARK: - Date-Filtered Computed Properties

    /// Whether the selected date is today.
    var isSelectedDateToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    /// HealthKit modalities that come from direct Apple Health queries.
    /// These are excluded from engine.recentEvents to avoid duplication.
    private static let healthKitModalities: Set<SensingModality> = [
        .steps, .heartRate, .hrv, .sleep, .workout, .activeEnergy,
        .basalEnergy, .respiratoryRate, .bloodOxygen, .noiseExposure,
    ]

    /// Sensing events for the selected date, sorted newest first.
    /// Phone sensing events come from engine.recentEvents; HealthKit events come
    /// from direct Apple Health queries (healthKitEvents) — no intermediate caching.
    /// For motion data: Watch workouts take priority over phone CoreMotion during
    /// overlapping time periods, since wrist-worn sensors are more accurate.
    var eventsForSelectedDate: [SensingEvent] {
        let calendar = Calendar.current
        // HealthKit data queried directly from Apple Health
        let healthData = healthKitEvents
            .filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }

        // Build time intervals covered by Watch workouts so we can suppress
        // phone CoreMotion events during those periods (Watch is more accurate).
        let workoutIntervals: [(start: Date, end: Date)] = healthData
            .filter { $0.modality == .workout }
            .compactMap { event in
                guard let durationStr = event.payload["duration"],
                      let duration = Double(durationStr), duration > 0 else { return nil }
                return (start: event.timestamp, end: event.timestamp.addingTimeInterval(duration))
            }

        // Phone sensing data from the engine (exclude HealthKit modalities to avoid duplication)
        let phoneSensing = engine.recentEvents
            .filter { !Self.healthKitModalities.contains($0.modality) }
            .filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
            .filter { event in
                // Drop phone motion events that overlap with Watch workout periods
                guard event.modality == .motion else { return true }
                let ts = event.timestamp
                return !workoutIntervals.contains { ts >= $0.start && ts <= $0.end }
            }

        return (phoneSensing + healthData).sorted { $0.timestamp > $1.timestamp }
    }

    /// Narrations for the selected date, sorted newest first.
    var narrationsForSelectedDate: [Narration] {
        let calendar = Calendar.current
        return narrations
            .filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Nudges for the selected date, sorted newest first.
    var nudgesForSelectedDate: [Nudge] {
        let calendar = Calendar.current
        return nudges
            .filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Food entries for the selected date, sorted newest first.
    var foodEntriesForSelectedDate: [FoodEntry] {
        let calendar = Calendar.current
        return foodEntries
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date > $1.date }
    }

    /// Activity entries for the selected date, sorted newest first.
    var activityEntriesForSelectedDate: [ActivityEntry] {
        let calendar = Calendar.current
        return activityEntries
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date > $1.date }
    }

    /// Deduplicated activity entries — all Health activities are kept (richer data).
    /// Motion sensing events that overlap with walking/running/cycling Health activities
    /// are removed from the filtered sensing events instead.
    var deduplicatedActivitiesForSelectedDate: [ActivityEntry] {
        activityEntriesForSelectedDate
    }

    /// All timeline items for the selected date, merged and sorted chronologically (newest first).
    /// Sensing events are filtered to remove noise (duplicate motion, redundant location, raw steps).
    /// Screen "off" events are hidden — their data is folded into the preceding "on" event.
    /// Health module meals and activities are included. Motion events overlapping with Health
    /// activities (walking, running, cycling) are removed to avoid duplication.
    var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []
        // Filter out non-display events from the timeline:
        // - Screen "off" events (data folded into preceding "on" event)
        // - Audio "listening" status (transient indicator, not a real event)
        // - Audio "speaker_update" (enriches existing transcript, not a row)
        let visibleSensingEvents = deduplicatedSensingEvents.filter { event in
            if event.modality == .screen && event.payload["state"] == "off" { return false }
            if event.modality == .audio {
                let status = event.payload["status"] ?? ""
                if status == "listening" || status == "speaker_update" { return false }
            }
            return true
        }
        items.append(contentsOf: visibleSensingEvents.map { .sensing($0) })
        items.append(contentsOf: narrationsForSelectedDate.map { .narration($0) })
        items.append(contentsOf: nudgesForSelectedDate.map { .nudge($0) })
        items.append(contentsOf: foodEntriesForSelectedDate.map { .meal($0) })
        items.append(contentsOf: deduplicatedActivitiesForSelectedDate.map { .activity($0) })
        return items.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Smart Timeline Filtering

    /// Activity types from Health module that overlap with motion sensor data.
    private static let overlappingActivityTypes = ["walking", "running", "cycling"]

    /// Sensing events after both noise filtering and Health activity deduplication.
    /// Motion events that overlap (within +/-10 minutes) with a Health module activity
    /// of a matching type (walking, running, cycling) are removed.
    private var deduplicatedSensingEvents: [SensingEvent] {
        let activities = activityEntriesForSelectedDate
        let overlapActivities = activities.filter { activity in
            Self.overlappingActivityTypes.contains(where: { activity.type.lowercased().contains($0) })
        }

        // If no overlapping Health activities, return the filtered events as-is
        guard !overlapActivities.isEmpty else { return filteredSensingEvents }

        let overlapWindow: TimeInterval = 600 // 10 minutes

        return filteredSensingEvents.filter { event in
            // Only check motion events for overlap
            guard event.modality == .motion else { return true }

            let motionActivityType = (event.payload["activityType"] ?? "").lowercased()

            // Check if this motion event overlaps with any Health activity
            for activity in overlapActivities {
                let activityTypeLower = activity.type.lowercased()
                let typesMatch = Self.overlappingActivityTypes.contains(where: { overlapType in
                    motionActivityType.contains(overlapType) && activityTypeLower.contains(overlapType)
                })

                if typesMatch {
                    let timeDiff = abs(event.timestamp.timeIntervalSince(activity.date))
                    if timeDiff <= overlapWindow {
                        return false // Remove this motion event — covered by Health activity
                    }
                }
            }
            return true
        }
    }

    /// Filters sensing events to show only semantically meaningful entries.
    /// - Steps: removed entirely (shown in overview card via daySummary.totalSteps)
    /// - Motion: HAR episode grouping — consecutive same-activity events within 5 minutes
    ///   are collapsed to keep only the first (transition) event
    /// - Location: only kept when position changed (>~100m) or 1+ hour gap since last
    /// - Screen, health, and other modalities: kept as-is
    private var filteredSensingEvents: [SensingEvent] {
        let dayEvents = eventsForSelectedDate

        // Separate events by modality for independent filtering
        let motionEvents = dayEvents
            .filter { $0.modality == .motion }
            .sorted { $0.timestamp < $1.timestamp }
        let locationEvents = dayEvents
            .filter { $0.modality == .location }
            .sorted { $0.timestamp < $1.timestamp }
        // Modalities that need time-window dedup (keep at most 1 per interval).
        let timeWindowModalities: [SensingModality: TimeInterval] = [
            .heartRate: 60,         // 1 per minute
            .hrv: 60,               // 1 per minute
            .activeEnergy: 300,     // 1 per 5 minutes
            .basalEnergy: 300,      // 1 per 5 minutes
            .respiratoryRate: 600,  // 1 per 10 minutes
            .bloodOxygen: 60,       // 1 per minute (Watch writes multiple samples per measurement)
            .noiseExposure: 600,    // 1 per 10 minutes (anomaly: 1 per minute)
            .bluetooth: 3600,       // 1 per hour
        ]

        let timeWindowEvents = dayEvents
            .filter { timeWindowModalities.keys.contains($0.modality) }
        let screenEvents = dayEvents
            .filter { $0.modality == .screen && $0.payload["state"] == "on" }
            .sorted { $0.timestamp < $1.timestamp }
        let excludedModalities: Set<SensingModality> = [.steps, .motion, .location, .screen]
        let passthroughEvents = dayEvents.filter { event in
            !excludedModalities.contains(event.modality)
            && !timeWindowModalities.keys.contains(event.modality)
        }

        // Time-window dedup: for each modality, keep at most 1 event per window.
        // Anomaly events (HR, noise) use a tighter window or bypass entirely.
        let noiseAnomalyThreshold: Double = 80  // dBA
        var filteredTimeWindow: [SensingEvent] = []
        for (modality, windowInterval) in timeWindowModalities {
            let modalityEvents = timeWindowEvents
                .filter { $0.modality == modality }
                .sorted { $0.timestamp < $1.timestamp }
            var lastKeptTime: Date?
            for event in modalityEvents {
                // HR anomalies always pass through
                if modality == .heartRate && event.payload["anomaly"] == "true" {
                    filteredTimeWindow.append(event)
                    continue
                }
                // Noise anomaly (>80 dBA): tighten window to 1 minute
                if modality == .noiseExposure,
                   let dbStr = event.payload["decibels"],
                   let db = Double(dbStr), db >= noiseAnomalyThreshold {
                    if let prevTime = lastKeptTime,
                       event.timestamp.timeIntervalSince(prevTime) < 60 {
                        continue
                    }
                    filteredTimeWindow.append(event)
                    lastKeptTime = event.timestamp
                    continue
                }
                if let prevTime = lastKeptTime,
                   event.timestamp.timeIntervalSince(prevTime) < windowInterval {
                    continue // Within window — skip
                }
                filteredTimeWindow.append(event)
                lastKeptTime = event.timestamp
            }
        }

        // Motion: HAR episode grouping
        // 1. Keep only when activity type changes from previous (transition events)
        // 2. If multiple events of the same type appear within 5 minutes, keep only the first
        let motionEpisodeWindow: TimeInterval = 300  // 5 minutes
        var filteredMotion: [SensingEvent] = []
        var lastActivityType: String?
        var lastMotionTime: Date?
        for event in motionEvents {
            let activityType = event.payload["activityType"] ?? "unknown"

            if activityType != lastActivityType {
                // Activity changed — this is a transition, always keep it
                filteredMotion.append(event)
                lastActivityType = activityType
                lastMotionTime = event.timestamp
            } else if let prevTime = lastMotionTime,
                      event.timestamp.timeIntervalSince(prevTime) >= motionEpisodeWindow {
                // Same activity but >5 min gap — could be a re-detection after gap, keep it
                filteredMotion.append(event)
                lastMotionTime = event.timestamp
            }
            // Otherwise: same activity within 5 min window — skip (noise)
        }

        // Location: prefer enriched events over raw ones for the same coordinates,
        // then keep only when position changed significantly or 1h+ gap.
        let locationDistanceThreshold: Double = 0.001  // ~100m in degrees
        let locationTimeGap: TimeInterval = 3600       // 1 hour

        // Separate enriched and raw location events
        let enrichedLocations = locationEvents.filter { $0.payload["enriched"] == "true" }
        let rawLocations = locationEvents.filter { $0.payload["enriched"] != "true" }

        // Remove raw events that have a matching enriched event (within 0.001 degrees)
        let deduplicatedLocations: [SensingEvent] = {
            var result = enrichedLocations
            for raw in rawLocations {
                guard let rawLatStr = raw.payload["latitude"],
                      let rawLngStr = raw.payload["longitude"],
                      let rawLat = Double(rawLatStr),
                      let rawLng = Double(rawLngStr) else {
                    result.append(raw)
                    continue
                }
                let hasEnrichedMatch = enrichedLocations.contains { enriched in
                    guard let eLat = enriched.payload["latitude"].flatMap(Double.init),
                          let eLng = enriched.payload["longitude"].flatMap(Double.init) else {
                        return false
                    }
                    return abs(rawLat - eLat) < locationDistanceThreshold
                        && abs(rawLng - eLng) < locationDistanceThreshold
                }
                if !hasEnrichedMatch {
                    result.append(raw)
                }
            }
            return result.sorted { $0.timestamp < $1.timestamp }
        }()

        var filteredLocation: [SensingEvent] = []
        var lastLat: Double?
        var lastLng: Double?
        var lastLocationTime: Date?
        for event in deduplicatedLocations {
            guard let latStr = event.payload["latitude"],
                  let lngStr = event.payload["longitude"],
                  let lat = Double(latStr),
                  let lng = Double(lngStr) else {
                continue
            }

            var shouldKeep = false

            if let prevLat = lastLat, let prevLng = lastLng, let prevTime = lastLocationTime {
                let latDelta = abs(lat - prevLat)
                let lngDelta = abs(lng - prevLng)
                let timeDelta = event.timestamp.timeIntervalSince(prevTime)

                // Position changed significantly
                if latDelta > locationDistanceThreshold || lngDelta > locationDistanceThreshold {
                    shouldKeep = true
                }
                // No location update for over an hour — show "still here"
                if timeDelta >= locationTimeGap {
                    shouldKeep = true
                }
            } else {
                // First location event of the day — always keep
                shouldKeep = true
            }

            if shouldKeep {
                filteredLocation.append(event)
                lastLat = lat
                lastLng = lng
                lastLocationTime = event.timestamp
            }
        }

        // Screen: aggregate "on" events into hourly buckets.
        // Each hourly event shows: number of opens, total on-duration, per-session durations.
        let calendar = Calendar.current
        var screenHourGroups: [Date: [SensingEvent]] = [:]
        for event in screenEvents {
            let hourStart = calendar.date(from: calendar.dateComponents(
                [.year, .month, .day, .hour], from: event.timestamp))!
            screenHourGroups[hourStart, default: []].append(event)
        }
        var aggregatedScreen: [SensingEvent] = []
        for (hourStart, events) in screenHourGroups {
            let count = events.count
            var totalDuration: Double = 0
            var sessionDurations: [String] = []
            for event in events {
                if let durStr = event.payload["onDuration"], let dur = Double(durStr), dur > 0 {
                    totalDuration += dur
                    sessionDurations.append("\(Int(dur))")
                } else {
                    sessionDurations.append("?")
                }
            }
            aggregatedScreen.append(SensingEvent(
                timestamp: hourStart,
                modality: .screen,
                payload: [
                    "state": "hourly_aggregate",
                    "count": "\(count)",
                    "totalDuration": "\(Int(totalDuration))",
                    "durations": sessionDurations.joined(separator: ","),
                ]
            ))
        }

        return filteredMotion + filteredLocation + filteredTimeWindow
            + aggregatedScreen + passthroughEvents
    }

    /// Aggregated overview summary for the selected date.
    var daySummary: DayOverviewSummary {
        let dayEvents = eventsForSelectedDate
        var summary = DayOverviewSummary()

        summary.eventCount = dayEvents.count
        summary.narrationCount = narrationsForSelectedDate.count
        summary.nudgeCount = nudgesForSelectedDate.count

        for event in dayEvents {
            switch event.modality {
            case .steps:
                if let steps = event.payload["steps"], let count = Int(steps) {
                    summary.totalSteps = max(summary.totalSteps, count)
                }
            case .motion:
                let activity = event.payload["activityType"] ?? "unknown"
                summary.activityBreakdown[activity, default: 0] += 1
            case .location:
                summary.locationChanges += 1
            case .screen:
                summary.screenEvents += 1
            default:
                break
            }
        }

        // Health module data: calories consumed from food entries
        for food in foodEntriesForSelectedDate {
            summary.totalCaloriesConsumed += food.calories ?? 0
        }

        // Health module data: activity minutes and calories burned from activity entries
        for activity in activityEntriesForSelectedDate {
            summary.totalActivityMinutes += activity.duration
            summary.totalCaloriesBurned += activity.caloriesBurned ?? 0
        }

        return summary
    }

    // MARK: - Channel Status

    /// Status information for each sensing channel.
    struct ChannelStatus: Identifiable {
        let id: SensingModality
        let modality: SensingModality
        let status: ChannelState
        let lastEventTime: Date?
        let eventCount: Int

        enum ChannelState {
            case active    // Received data in last 30 min
            case stale     // Received data but >30 min ago
            case inactive  // No data yet or sensing disabled
        }
    }

    /// Status of all sensing channels for the status bar.
    /// Combines raw engine events (phone sensors) with HealthKit events
    /// to give an accurate picture of all data sources.
    var channelStatuses: [ChannelStatus] {
        let channelModalities: [SensingModality] = [
            .motion, .steps, .heartRate, .hrv, .bloodOxygen,
            .respiratoryRate, .sleep, .workout, .activeEnergy, .basalEnergy,
            .noiseExposure, .location, .screen, .battery, .call, .wifi,
            .bluetooth, .audio, .photo
        ]
        let now = Date()
        let thirtyMinAgo = now.addingTimeInterval(-1800)
        let calendar = Calendar.current

        // Combine engine events (phone sensors) + HealthKit events for today
        let todayEngineEvents = engine.recentEvents
            .filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
        let todayHealthEvents = healthKitEvents
            .filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
        let allTodayEvents = todayEngineEvents + todayHealthEvents

        return channelModalities.compactMap { modality in
            let events = allTodayEvents.filter { $0.modality == modality }
            let latestTime = events.max(by: { $0.timestamp < $1.timestamp })?.timestamp
            let count = events.count

            guard count > 0 else { return nil }

            let state: ChannelStatus.ChannelState
            if !sensingEnabled {
                state = .inactive
            } else if let latest = latestTime, latest > thirtyMinAgo {
                state = .active
            } else {
                state = .stale
            }

            return ChannelStatus(
                id: modality,
                modality: modality,
                status: state,
                lastEventTime: latestTime,
                eventCount: count
            )
        }
    }

    /// Latest heart rate reading from today's events.
    var latestHeartRate: String? {
        eventsForSelectedDate
            .first(where: { $0.modality == .heartRate })
            .flatMap { $0.payload["bpm"] }
    }

    /// Latest battery level from today's events.
    var latestBatteryLevel: String? {
        eventsForSelectedDate
            .first(where: { $0.modality == .battery })
            .flatMap { $0.payload["level"] }
    }

    /// Current activity type from the most recent motion event today.
    var currentActivityType: String? {
        eventsForSelectedDate
            .first(where: { $0.modality == .motion })
            .flatMap { $0.payload["activityType"]?.capitalized }
    }

    /// Semantic location label from the most recent location event today.
    var latestLocationLabel: String? {
        guard let event = eventsForSelectedDate.first(where: { $0.modality == .location }) else { return nil }
        if let desc = event.payload["description"], !desc.isEmpty, desc != "unknown" {
            return desc
        }
        if let lat = event.payload["latitude"], let lon = event.payload["longitude"] {
            return "(\(lat), \(lon))"
        }
        return nil
    }

    /// Primary mood emoji from the latest narration's affect analysis today.
    var latestMoodEmoji: String? {
        guard let narration = narrationsForSelectedDate.first,
              let emotion = narration.affectAnalysis?.primaryEmotion ?? narration.extractedMood else {
            return nil
        }
        return moodToEmoji(emotion)
    }

    /// Convert a mood/emotion string to a representative emoji.
    private func moodToEmoji(_ mood: String) -> String {
        switch mood.lowercased() {
        case "joy", "happy", "happiness": return "😊"
        case "sadness", "sad": return "😢"
        case "anger", "angry": return "😤"
        case "fear", "anxious", "anxiety": return "😰"
        case "surprise", "surprised": return "😮"
        case "disgust": return "😒"
        case "neutral", "calm": return "😐"
        case "love": return "🥰"
        case "excitement", "excited": return "🤩"
        default: return "🙂"
        }
    }

    // MARK: - Computed Properties

    /// Events filtered by the selected modality, or all events if no filter.
    var filteredEvents: [SensingEvent] {
        if let modality = selectedModality {
            return engine.events(for: modality)
        }
        return engine.recentEvents
    }

    /// Formatted string for the last sync time.
    var lastSyncTimeString: String? {
        guard let syncTime = engine.lastSyncTime else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: syncTime, relativeTo: Date())
    }

    /// Status text for the auto-sync display row.
    var autoSyncStatusText: String {
        let pending = engine.pendingEventCount
        if let lastSync = lastSyncTimeString {
            if pending > 0 {
                return "Auto-sync \u{00B7} \(pending) pending \u{00B7} Last: \(lastSync)"
            }
            return "Auto-sync \u{00B7} Last: \(lastSync)"
        }
        if pending > 0 {
            return "Auto-sync \u{00B7} \(pending) pending"
        }
        return "Auto-sync enabled"
    }

    // MARK: - Init

    init() {
        // Migrate UserDefaults keys from popo → bobo (one-time after rename)
        Self.migrateStorageKeys()

        // Restore persisted preference
        let wasEnabled = UserDefaults.standard.bool(forKey: StorageKeys.sensingEnabled)
        if wasEnabled {
            sensingEnabled = true
            engine.startSensing()
            startNudgeTimer()
            startHealthKitRefreshTimer()
        }

        // Load narrations, nudges, and health data from local storage
        loadNarrations()
        loadNudges()
        loadFoodEntries()
        loadActivityEntries()

        // Fetch HealthKit data directly from Apple Health
        requestHealthKitAuthAndFetch()
    }

    /// Request HealthKit read authorization (if not yet granted) and fetch data.
    private func requestHealthKitAuthAndFetch() {
        guard let store = Self.healthStore else { return }
        var readTypes = Set<HKObjectType>()
        if let t = HKQuantityType.quantityType(forIdentifier: .heartRate) { readTypes.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { readTypes.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { readTypes.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) { readTypes.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) { readTypes.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) { readTypes.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure) { readTypes.insert(t) }
        if let t = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { readTypes.insert(t) }
        readTypes.insert(HKWorkoutType.workoutType())

        store.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, error in
            print("[BoBo] HealthKit auth: success=\(success), error=\(error?.localizedDescription ?? "none")")
            if success {
                Task { @MainActor in
                    self?.fetchHealthKitEvents()
                }
            }
        }
    }

    /// Migrate UserDefaults keys from the old "popo" naming to "bobo".
    /// Only runs once; subsequent calls are no-ops.
    private static func migrateStorageKeys() {
        let ud = UserDefaults.standard
        let migrationKey = "ryanhub_bobo_migrated_from_popo"
        guard !ud.bool(forKey: migrationKey) else { return }

        let keyMap: [(old: String, new: String)] = [
            ("ryanhub_popo_sensing_enabled", StorageKeys.sensingEnabled),
            ("ryanhub_popo_narrations", StorageKeys.narrations),
            ("ryanhub_popo_nudges", StorageKeys.nudges),
            ("ryanhub_popo_last_nudge_generation", StorageKeys.lastNudgeGeneration),
            ("ryanhub_popo_last_sync_time", "ryanhub_bobo_last_sync_time"),
            // HealthSensor fetch timestamps
            ("popo_health_lastFetch_heartRate", "bobo_health_lastFetch_heartRate"),
            ("popo_health_lastFetch_hrv", "bobo_health_lastFetch_hrv"),
            ("popo_health_lastFetch_sleep", "bobo_health_lastFetch_sleep"),
            ("popo_health_lastFetch_workout", "bobo_health_lastFetch_workout"),
            ("popo_health_lastFetch_activeEnergy", "bobo_health_lastFetch_activeEnergy"),
            ("popo_health_lastFetch_basalEnergy", "bobo_health_lastFetch_basalEnergy"),
            ("popo_health_lastFetch_respiratoryRate", "bobo_health_lastFetch_respiratoryRate"),
            ("popo_health_lastFetch_bloodOxygen", "bobo_health_lastFetch_bloodOxygen"),
            ("popo_health_lastFetch_noiseExposure", "bobo_health_lastFetch_noiseExposure"),
        ]

        for (old, new) in keyMap {
            if ud.object(forKey: old) != nil && ud.object(forKey: new) == nil {
                ud.set(ud.object(forKey: old), forKey: new)
                print("[BoBo] Migrated key: \(old) → \(new)")
            }
        }
        ud.set(true, forKey: migrationKey)
    }

    // MARK: - Day Navigation

    /// Navigate to a day offset from the current selected date.
    func navigateDay(offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) else { return }
        // Don't navigate past today
        if newDate <= Date() {
            selectedDate = newDate
        }
    }

    /// Jump back to today.
    func goToToday() {
        selectedDate = Date()
    }

    // MARK: - Expand/Collapse

    /// Toggle whether a timeline item is expanded.
    func toggleExpanded(_ id: UUID) {
        if expandedItemIDs.contains(id) {
            expandedItemIDs.remove(id)
        } else {
            expandedItemIDs.insert(id)
        }
    }

    /// Check if a timeline item is expanded.
    func isExpanded(_ id: UUID) -> Bool {
        expandedItemIDs.contains(id)
    }

    // MARK: - Sync State

    /// Whether a sync operation is currently in progress (mirrors engine state).
    var isSyncing: Bool {
        engine.isSyncing
    }

    /// Error from the last sync attempt, if any.
    var lastSyncError: String? {
        engine.lastSyncError
    }

    // MARK: - Actions

    /// Force an immediate sync of pending events.
    func syncNow() async {
        await engine.syncPendingEvents()
    }

    // MARK: - Narration Recording

    /// Start recording a voice narration diary entry.
    func startNarration() {
        guard narrationState == .idle || narrationState == .done || isNarrationError else {
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            narrationState = .error("Microphone access denied")
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "narration_\(UUID().uuidString).m4a"
        let url = tempDir.appendingPathComponent(fileName)
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            narrationState = .recording
            recordingStartTime = Date()
            narrationDuration = 0
            narrationAudioLevels = []

            // Sample audio levels at ~30fps and update duration
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                guard let self, let start = self.recordingStartTime else { return }
                self.narrationDuration = Date().timeIntervalSince(start)

                self.audioRecorder?.updateMeters()
                let power = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
                let clampedPower = max(power, -50)
                let normalized = CGFloat((clampedPower + 50) / 50)
                self.narrationAudioLevels.append(normalized)
            }
            recordingTimer = timer
        } catch {
            narrationState = .error("Failed to start recording")
        }
    }

    /// Stop recording, upload audio, and create a narration entry.
    func stopNarration() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()

        guard narrationState == .recording else { return }

        guard let url = recordingURL,
              let data = try? Data(contentsOf: url) else {
            narrationState = .error("Failed to read recording")
            return
        }

        let duration = narrationDuration
        guard duration >= 1.0 else {
            // Too short, discard
            narrationState = .idle
            narrationDuration = 0
            narrationAudioLevels = []
            try? FileManager.default.removeItem(at: url)
            return
        }

        narrationState = .uploading

        let narrationId = UUID()

        // Insert a placeholder narration IMMEDIATELY so it appears in the timeline
        // right away — before the async upload/analysis begins.
        let narration = Narration(
            id: narrationId,
            timestamp: Date(),
            transcript: "",
            duration: duration,
            audioFileRef: nil  // Will be set after upload
        )
        narrations.insert(narration, at: 0)
        saveNarrations()
        print("[BoboVM] Voice narration \(narrationId) inserted into timeline (pending upload)")

        Task {
            do {
                // Sync the placeholder narration to the server FIRST so it exists
                // in bobo_narrations.json before any background analysis tries to
                // update it with the transcript.
                if let index = narrations.firstIndex(where: { $0.id == narrationId }) {
                    await syncNarrationToServer(narrations[index])
                }

                let filename = try await uploadNarrationAudio(data: data, narrationId: narrationId)
                print("[BoboVM] Audio uploaded: \(filename)")

                // Update the placeholder with the server-assigned filename
                if let index = narrations.firstIndex(where: { $0.id == narrationId }) {
                    narrations[index].audioFileRef = filename
                    saveNarrations()

                    // Re-sync with filename so the server copy has it too
                    await syncNarrationToServer(narrations[index])
                }

                // Request server-side analysis (transcription + affect).
                // The /bobo/narrations/analyze endpoint runs Whisper + emotion model
                // synchronously and returns the result inline.
                var analysisResult = await requestNarrationAnalysis(filename: filename, narrationId: narrationId)

                // If the synchronous call failed (server busy, Whisper unavailable, etc.),
                // the audio upload may have triggered background analysis. Poll the server
                // for the updated narration until transcript appears (up to 60s).
                if analysisResult == nil {
                    print("[BoboVM] Synchronous analysis returned nil, polling for background result...")
                    analysisResult = await pollForNarrationAnalysis(narrationId: narrationId, maxAttempts: 12, intervalSeconds: 5)
                }

                if let analysis = analysisResult {
                    // Update the local entry with transcript and affect data
                    if let index = narrations.firstIndex(where: { $0.id == narrationId }) {
                        narrations[index].transcript = analysis.transcript
                        narrations[index].affectAnalysis = analysis.affect
                        narrations[index].extractedMood = analysis.affect?.primaryEmotion
                        saveNarrations()
                        print("[BoboVM] Narration \(narrationId) updated with transcript: \(analysis.transcript.prefix(80))...")

                        // Re-sync updated narration
                        await syncNarrationToServer(narrations[index])
                    }
                } else {
                    print("[BoboVM] WARNING: No analysis result for narration \(narrationId) — transcript will remain empty")
                }

                narrationState = .done

                // Auto-reset to idle after a short delay
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if narrationState == .done {
                    narrationState = .idle
                    narrationDuration = 0
                    narrationAudioLevels = []
                }
            } catch {
                print("[BoboVM] Upload failed for narration \(narrationId): \(error.localizedDescription)")
                // Upload failed but the narration placeholder is already in the timeline.
                // Keep it there so the user can see it was recorded, even if upload failed.
                narrationState = .error("Upload failed: \(error.localizedDescription)")
            }

            // Clean up temp file
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Cancel an in-progress narration recording.
    func cancelNarration() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        narrationState = .idle
        narrationDuration = 0
        narrationAudioLevels = []

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Text Diary

    /// Submit a text diary entry. Creates a narration with no audio,
    /// saves locally, syncs to server, and requests affect analysis on the text.
    func addTextDiary(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSubmittingTextDiary = true

        var narration = Narration(
            id: UUID(),
            timestamp: Date(),
            transcript: trimmed,
            duration: 0,
            audioFileRef: nil
        )

        narrations.insert(narration, at: 0)
        saveNarrations()
        textDiaryInput = ""

        Task {
            // Sync to server
            await syncNarrationToServer(narration)

            // Request affect analysis on the text (skip audio transcription)
            if let analysis = await requestTextAnalysis(narration) {
                narration.affectAnalysis = analysis.affect
                narration.extractedMood = analysis.affect?.primaryEmotion

                // Update the local entry
                if let index = narrations.firstIndex(where: { $0.id == narration.id }) {
                    narrations[index] = narration
                    saveNarrations()
                }

                // Re-sync updated narration
                await syncNarrationToServer(narration)
            }

            isSubmittingTextDiary = false
        }
    }

    // MARK: - Camera Catch

    /// Save a photo to disk and add it as a timeline event.
    func savePhoto(_ imageData: Data) {
        let event = SensingEvent(modality: .photo, payload: [:])

        // Save JPEG to /Documents/bobo/photos/{eventId}.jpg
        let photosDir = Self.photosDirectory
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        let fileURL = photosDir.appendingPathComponent("\(event.id.uuidString).jpg")
        try? imageData.write(to: fileURL)

        // Store reference in payload
        var mutableEvent = event
        mutableEvent.payload["imageFileId"] = event.id.uuidString

        engine.recordEvent(mutableEvent)
    }

    /// Directory for storing timeline photos.
    private static var photosDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bobo/photos", isDirectory: true)
    }

    /// Load a photo from disk by event ID.
    static func loadPhoto(for fileId: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bobo/photos/\(fileId).jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Request affect analysis for a text-only narration (no audio file to transcribe).
    /// Sends the transcript directly to the analysis endpoint with a flag to skip Whisper.
    private func requestTextAnalysis(_ narration: Narration) async -> NarrationAnalysisResult? {
        let endpoint = "\(Self.bridgeBaseURL)/bobo/narrations/analyze"
        guard let url = URL(string: endpoint) else { return nil }

        let payload: [String: String] = [
            "narration_id": narration.id.uuidString,
            "transcript": narration.transcript,
            "text_only": "true"
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 60

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                print("[BoboVM] Text analysis server returned status \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }

            // Do NOT use .convertFromSnakeCase — AffectAnalysis has explicit CodingKeys
            let decoder = JSONDecoder()
            let result = try decoder.decode(NarrationAnalysisResponse.self, from: data)

            return NarrationAnalysisResult(
                transcript: result.transcript ?? narration.transcript,
                affect: result.affect
            )
        } catch {
            print("[BoboVM] Text analysis request failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Narration Networking

    /// Upload raw audio data to the bridge server. Returns the server-assigned filename.
    private func uploadNarrationAudio(data: Data, narrationId: UUID) async throws -> String {
        let endpoint = "\(Self.bridgeBaseURL)/bobo/audio"
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
        request.setValue("narration_\(narrationId.uuidString).m4a", forHTTPHeaderField: "X-Filename")
        request.setValue(narrationId.uuidString, forHTTPHeaderField: "X-Narration-Id")
        request.httpBody = data
        request.timeoutInterval = 60

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw URLError(.badServerResponse, userInfo: [
                NSLocalizedDescriptionKey: "Server returned \(statusCode)"
            ])
        }

        let result = try JSONDecoder().decode(NarrationAudioUploadResponse.self, from: responseData)
        return result.filename
    }

    /// Sync a narration entry to the bridge server's /bobo/narrations endpoint.
    private func syncNarrationToServer(_ narration: Narration) async {
        let endpoint = "\(Self.bridgeBaseURL)/bobo/narrations"
        guard let url = URL(string: endpoint) else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let body = try? encoder.encode([narration]) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 30

        _ = try? await URLSession.shared.data(for: request)
    }

    /// Request the bridge server to transcribe and analyze a narration.
    private func requestNarrationAnalysis(
        filename: String,
        narrationId: UUID
    ) async -> NarrationAnalysisResult? {
        let endpoint = "\(Self.bridgeBaseURL)/bobo/narrations/analyze"
        guard let url = URL(string: endpoint) else { return nil }

        let payload: [String: String] = [
            "filename": filename,
            "narration_id": narrationId.uuidString
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 120  // Transcription can take a while

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                print("[BoboVM] Analysis server returned status \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }

            // Do NOT use .convertFromSnakeCase here — AffectAnalysis already has
            // explicit CodingKeys mapping snake_case JSON keys (e.g. "primary_emotion").
            // Combining .convertFromSnakeCase with custom CodingKeys causes double-
            // conversion: the strategy converts "primary_emotion" -> "primaryEmotion",
            // then tries to match against CodingKey.stringValue "primary_emotion" — no match.
            let decoder = JSONDecoder()
            let result = try decoder.decode(NarrationAnalysisResponse.self, from: data)

            return NarrationAnalysisResult(
                transcript: result.transcript ?? "",
                affect: result.affect
            )
        } catch {
            print("[BoboVM] Analysis request failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Poll the server for a narration's analysis results.
    /// The audio upload endpoint triggers background Whisper transcription; this method
    /// fetches all narrations from `/bobo/narrations` and checks if the target narration
    /// has a non-empty transcript, retrying up to `maxAttempts` times.
    private func pollForNarrationAnalysis(
        narrationId: UUID,
        maxAttempts: Int,
        intervalSeconds: UInt64
    ) async -> NarrationAnalysisResult? {
        let endpoint = "\(Self.bridgeBaseURL)/bobo/narrations"
        guard let url = URL(string: endpoint) else { return nil }

        for attempt in 1...maxAttempts {
            try? await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)

            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 15

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else {
                    continue
                }

                // Server stores narrations as JSON with snake_case keys matching
                // AffectAnalysis.CodingKeys — decode without key conversion strategy.
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let serverNarrations = try decoder.decode([Narration].self, from: data)

                if let match = serverNarrations.first(where: { $0.id == narrationId }),
                   !match.transcript.isEmpty {
                    print("[BoboVM] Poll attempt \(attempt): found transcript for \(narrationId)")
                    return NarrationAnalysisResult(
                        transcript: match.transcript,
                        affect: match.affectAnalysis
                    )
                }

                print("[BoboVM] Poll attempt \(attempt)/\(maxAttempts): transcript still empty")
            } catch {
                print("[BoboVM] Poll attempt \(attempt) error: \(error.localizedDescription)")
            }
        }

        print("[BoboVM] Polling exhausted for narration \(narrationId)")
        return nil
    }

    // MARK: - Nudge Generation Pipeline

    /// Generate nudges by calling the bridge server's analysis endpoint.
    /// Sends recent sensing events, narrations, and day summary for AI analysis.
    func generateNudges() async {
        guard !isGeneratingNudges else { return }
        isGeneratingNudges = true
        defer { isGeneratingNudges = false }

        let endpoint = "\(Self.bridgeBaseURL)/bobo/analyze"
        guard let url = URL(string: endpoint) else { return }

        // Gather recent sensing events from the filtered timeline (WYSIWYG —
        // AI sees exactly what the user sees, not raw data).
        let sixHoursAgo = Date().addingTimeInterval(-6 * 3600)
        let recentSensingEvents = timelineItems
            .compactMap { item -> SensingEvent? in
                if case .sensing(let event) = item { return event }
                return nil
            }
            .filter { $0.timestamp > sixHoursAgo }
            .prefix(200)

        // Encode sensing events as simplified dictionaries
        let eventDicts: [[String: String]] = recentSensingEvents.map { event in
            var dict = event.payload
            dict["modality"] = event.modality.rawValue
            dict["timestamp"] = ISO8601DateFormatter().string(from: event.timestamp)
            return dict
        }

        // Gather today's narrations
        let narrationDicts: [[String: Any]] = narrationsForSelectedDate.map { narration in
            var dict: [String: Any] = [
                "timestamp": ISO8601DateFormatter().string(from: narration.timestamp),
                "transcript": narration.transcript,
                "duration": narration.duration
            ]
            if let mood = narration.extractedMood {
                dict["mood"] = mood
            }
            if let affect = narration.affectAnalysis {
                if let primaryEmotion = affect.primaryEmotion { dict["primary_emotion"] = primaryEmotion }
                if let moodScore = affect.mood { dict["mood_score"] = moodScore }
                if let energy = affect.energy { dict["energy"] = energy }
                if let stress = affect.stress { dict["stress"] = stress }
            }
            return dict
        }

        // Day summary
        let summary = daySummary
        let summaryDict: [String: Any] = [
            "total_steps": summary.totalSteps,
            "activity_breakdown": summary.activityBreakdown,
            "location_changes": summary.locationChanges,
            "screen_events": summary.screenEvents,
            "narration_count": summary.narrationCount,
            "event_count": summary.eventCount
        ]

        let payload: [String: Any] = [
            "events": eventDicts,
            "narrations": narrationDicts,
            "day_summary": summaryDict
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 60

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                print("[BoboVM] Nudge generation server returned error")
                return
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            let result = try decoder.decode(NudgeAnalysisResponse.self, from: data)

            // Insert new nudges
            for nudgeData in result.nudges {
                let nudge = Nudge(
                    content: nudgeData.content,
                    trigger: nudgeData.trigger ?? "sensing_analysis",
                    type: NudgeType(rawValue: nudgeData.type) ?? .insight,
                    priority: nudgeData.priority ?? "normal",
                    relatedModalities: nudgeData.relatedModalities
                )
                nudges.insert(nudge, at: 0)

                // Send local push notification for high-priority nudges
                if nudge.priority == "high" || nudge.type == .alert {
                    sendNudgeNotification(nudge)
                }
            }

            saveNudges()

            // Update last generation time
            UserDefaults.standard.set(
                Date().timeIntervalSince1970,
                forKey: StorageKeys.lastNudgeGeneration
            )

            print("[BoboVM] Generated \(result.nudges.count) nudges")
        } catch {
            print("[BoboVM] Nudge generation failed: \(error.localizedDescription)")
        }
    }

    /// Check if nudge generation should run on foreground (>2 hours since last run).
    func checkAndGenerateNudgesIfNeeded() async {
        guard sensingEnabled else { return }
        let lastGeneration = UserDefaults.standard.double(forKey: StorageKeys.lastNudgeGeneration)
        let timeSinceLast = Date().timeIntervalSince1970 - lastGeneration
        if lastGeneration == 0 || timeSinceLast > Self.nudgeInterval {
            await generateNudges()
        }
    }

    /// Acknowledge a nudge by marking it as read.
    func acknowledgeNudge(_ nudge: Nudge) {
        guard let index = nudges.firstIndex(where: { $0.id == nudge.id }) else { return }
        nudges[index].acknowledged = true
        saveNudges()
    }

    // MARK: - Nudge Timer

    /// Start the periodic nudge generation timer (every 2 hours).
    private func startNudgeTimer() {
        stopNudgeTimer()
        nudgeTimer = Timer.scheduledTimer(withTimeInterval: Self.nudgeInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.generateNudges()
            }
        }
    }

    /// Stop the nudge generation timer.
    private func stopNudgeTimer() {
        nudgeTimer?.invalidate()
        nudgeTimer = nil
    }

    // MARK: - HealthKit Refresh Timer

    /// Start a periodic timer that re-fetches HealthKit data every 30 seconds while in foreground.
    private func startHealthKitRefreshTimer() {
        stopHealthKitRefreshTimer()
        healthKitRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchHealthKitEvents()
            }
        }
    }

    /// Stop the HealthKit refresh timer.
    private func stopHealthKitRefreshTimer() {
        healthKitRefreshTimer?.invalidate()
        healthKitRefreshTimer = nil
    }

    /// Send a local push notification for a nudge.
    private func sendNudgeNotification(_ nudge: Nudge) {
        let content = UNMutableNotificationContent()
        content.title = "Bo"
        content.body = nudge.content
        content.sound = .default
        content.userInfo = ["destination": "bobo"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: nudge.id.uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    private var isNarrationError: Bool {
        if case .error = narrationState { return true }
        return false
    }

    /// Base URL for the bridge server.
    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? AppState.defaultFoodAnalysisURL
    }

    // MARK: - Local Persistence

    private func loadNarrations() {
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.narrations) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        narrations = (try? decoder.decode([Narration].self, from: data)) ?? []
    }

    private func saveNarrations() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(narrations) {
            UserDefaults.standard.set(data, forKey: StorageKeys.narrations)
        }
    }

    private func loadNudges() {
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.nudges) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        nudges = (try? decoder.decode([Nudge].self, from: data)) ?? []
    }

    /// Persist nudges to UserDefaults and sync to bridge server.
    func saveNudges() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(nudges) {
            UserDefaults.standard.set(data, forKey: StorageKeys.nudges)
        }

        // Sync to bridge server in background
        Task {
            await syncNudgesToServer()
        }
    }

    /// Sync nudges to the bridge server.
    private func syncNudgesToServer() async {
        let endpoint = "\(Self.bridgeBaseURL)/bobo/nudges"
        guard let url = URL(string: endpoint) else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let body = try? encoder.encode(nudges) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 30

        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Health Data Loading

    /// Load food entries from the Health module's UserDefaults storage.
    private func loadFoodEntries() {
        guard let data = UserDefaults.standard.data(forKey: "ryanhub_health_food") else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        foodEntries = (try? decoder.decode([FoodEntry].self, from: data)) ?? []
    }

    /// Load activity entries from the Health module's UserDefaults storage.
    private func loadActivityEntries() {
        guard let data = UserDefaults.standard.data(forKey: "ryanhub_health_activity") else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        activityEntries = (try? decoder.decode([ActivityEntry].self, from: data)) ?? []
    }

    /// Refresh all health data when app becomes active.
    /// Loads food/activity entries from UserDefaults and queries HealthKit directly.
    func refreshHealthData() {
        loadFoodEntries()
        loadActivityEntries()
        fetchHealthKitEvents()
    }

    // MARK: - Direct HealthKit Queries

    /// Shared HealthKit store for direct queries.
    private static let healthStore: HKHealthStore? = {
        HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }()

    /// Fetch all HealthKit data for the selected date directly from Apple Health.
    /// This is the simple, correct approach: HealthKit is the persistent store,
    /// just query it and display. No intermediate caching needed.
    func fetchHealthKitEvents() {
        guard let store = Self.healthStore else {
            print("[BoBo] HealthKit not available")
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let dayStart = calendar.startOfDay(for: selectedDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        // Query all HealthKit types in parallel, collect results
        var allEvents: [SensingEvent] = []
        let group = DispatchGroup()

        // Step count — daily total via statistics query
        if let type = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            group.enter()
            let statsQuery = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                defer { group.leave() }
                guard let sum = statistics?.sumQuantity() else { return }
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                guard steps > 0 else { return }
                allEvents.append(SensingEvent(
                    timestamp: dayStart,
                    modality: .steps,
                    payload: [
                        "steps": "\(steps)",
                        "source": "healthkit",
                    ]
                ))
            }
            store.execute(statsQuery)
        }

        // Heart rate
        if let type = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            group.enter()
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                defer { group.leave() }
                guard let samples = samples as? [HKQuantitySample] else { return }
                // Group by calendar minute for aggregation
                var minuteGroups: [Date: [Double]] = [:]
                for s in samples {
                    let bpm = s.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    let mc = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: s.startDate)
                    let minuteStart = calendar.date(from: mc) ?? s.startDate
                    minuteGroups[minuteStart, default: []].append(bpm)
                }
                for (minute, bpms) in minuteGroups {
                    let avg = bpms.reduce(0, +) / Double(bpms.count)
                    allEvents.append(SensingEvent(timestamp: minute, modality: .heartRate, payload: [
                        "bpm": String(format: "%.0f", avg),
                        "min": String(format: "%.0f", bpms.min() ?? avg),
                        "max": String(format: "%.0f", bpms.max() ?? avg),
                        "count": "\(bpms.count)",
                        "source": samples.first?.sourceRevision.source.name ?? "watch",
                    ]))
                }
            }
            store.execute(q)
        }

        // HRV
        if let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            group.enter()
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                defer { group.leave() }
                guard let samples = samples as? [HKQuantitySample] else { return }
                for s in samples {
                    let sdnn = s.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    allEvents.append(SensingEvent(timestamp: s.startDate, modality: .hrv, payload: [
                        "sdnn": String(format: "%.1f", sdnn),
                        "source": s.sourceRevision.source.name,
                    ]))
                }
            }
            store.execute(q)
        }

        // Sleep
        if let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            group.enter()
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                defer { group.leave() }
                guard let samples = samples as? [HKCategorySample] else { return }
                let formatter = ISO8601DateFormatter()
                for s in samples {
                    let stage: String
                    switch s.value {
                    case HKCategoryValueSleepAnalysis.inBed.rawValue: stage = "inBed"
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: stage = "asleep"
                    case HKCategoryValueSleepAnalysis.awake.rawValue: stage = "awake"
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue: stage = "core"
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: stage = "deep"
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue: stage = "rem"
                    default: stage = "unknown"
                    }
                    allEvents.append(SensingEvent(timestamp: s.startDate, modality: .sleep, payload: [
                        "stage": stage,
                        "startDate": formatter.string(from: s.startDate),
                        "endDate": formatter.string(from: s.endDate),
                        "source": s.sourceRevision.source.name,
                    ]))
                }
            }
            store.execute(q)
        }

        // Workouts
        group.enter()
        let wq = HKSampleQuery(sampleType: HKWorkoutType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            defer { group.leave() }
            guard let samples = samples as? [HKWorkout] else { return }
            for w in samples {
                let cal = w.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                allEvents.append(SensingEvent(timestamp: w.startDate, modality: .workout, payload: [
                    "type": Self.workoutTypeString(from: w.workoutActivityType),
                    "duration": String(format: "%.0f", w.duration),
                    "calories": cal.map { String(format: "%.0f", $0) } ?? "unknown",
                    "source": w.sourceRevision.source.name,
                ]))
            }
        }
        store.execute(wq)

        // Active energy — aggregate by hour
        if let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            group.enter()
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                defer { group.leave() }
                guard let samples = samples as? [HKQuantitySample] else { return }
                let hourlyEvents = Self.aggregateEnergyByHour(samples: samples, modality: .activeEnergy, calendar: calendar, now: now)
                allEvents.append(contentsOf: hourlyEvents)
            }
            store.execute(q)
        }

        // Basal energy — aggregate by hour
        if let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            group.enter()
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                defer { group.leave() }
                guard let samples = samples as? [HKQuantitySample] else { return }
                let hourlyEvents = Self.aggregateEnergyByHour(samples: samples, modality: .basalEnergy, calendar: calendar, now: now)
                allEvents.append(contentsOf: hourlyEvents)
            }
            store.execute(q)
        }

        // Respiratory rate
        if let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
            group.enter()
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                defer { group.leave() }
                guard let samples = samples as? [HKQuantitySample] else { return }
                for s in samples {
                    let bpm = s.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    allEvents.append(SensingEvent(timestamp: s.startDate, modality: .respiratoryRate, payload: [
                        "breathsPerMin": String(format: "%.1f", bpm),
                        "source": s.sourceRevision.source.name,
                    ]))
                }
            }
            store.execute(q)
        }

        // Blood oxygen
        if let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            group.enter()
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                defer { group.leave() }
                guard let samples = samples as? [HKQuantitySample] else { return }
                for s in samples {
                    let pct = s.quantity.doubleValue(for: HKUnit.percent()) * 100
                    allEvents.append(SensingEvent(timestamp: s.startDate, modality: .bloodOxygen, payload: [
                        "spo2": String(format: "%.1f", pct),
                        "source": s.sourceRevision.source.name,
                    ]))
                }
            }
            store.execute(q)
        }

        // Noise exposure
        if let type = HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure) {
            group.enter()
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                defer { group.leave() }
                guard let samples = samples as? [HKQuantitySample] else { return }
                for s in samples {
                    let db = s.quantity.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel())
                    allEvents.append(SensingEvent(timestamp: s.startDate, modality: .noiseExposure, payload: [
                        "decibels": String(format: "%.1f", db),
                        "source": s.sourceRevision.source.name,
                    ]))
                }
            }
            store.execute(q)
        }

        // Wait for all queries to complete, then update on main thread
        DispatchQueue.global().async {
            group.wait()
            print("[BoBo] HealthKit direct query: fetched \(allEvents.count) events for \(self.selectedDate)")
            Task { @MainActor in
                self.healthKitEvents = allEvents
            }
        }
    }

    /// Convert HKWorkoutActivityType to display string.
    private static func workoutTypeString(from type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "running"
        case .walking: return "walking"
        case .cycling: return "cycling"
        case .swimming: return "swimming"
        case .yoga: return "yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "strength"
        case .highIntensityIntervalTraining: return "hiit"
        case .elliptical: return "elliptical"
        case .rowing: return "rowing"
        case .stairClimbing: return "stairs"
        case .hiking: return "hiking"
        default: return "other"
        }
    }

    /// Aggregate energy samples into hourly windows.
    /// Each window is timestamped at the hour start (e.g. 9:00 AM).
    /// The current hour is marked with `ongoing: true` so the display can show "so far".
    private static func aggregateEnergyByHour(
        samples: [HKQuantitySample],
        modality: SensingModality,
        calendar: Calendar,
        now: Date
    ) -> [SensingEvent] {
        var hourlyBuckets: [Date: Double] = [:]
        for s in samples {
            let kcal = s.quantity.doubleValue(for: .kilocalorie())
            let comps = calendar.dateComponents([.year, .month, .day, .hour], from: s.startDate)
            let hourStart = calendar.date(from: comps) ?? s.startDate
            hourlyBuckets[hourStart, default: 0] += kcal
        }

        let currentHourComps = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        let currentHourStart = calendar.date(from: currentHourComps)

        let source = samples.first?.sourceRevision.source.name ?? "watch"
        return hourlyBuckets.map { (hourStart, totalKcal) in
            let nextHour = calendar.date(byAdding: .hour, value: 1, to: hourStart)!
            let hourLabel = Self.hourRangeLabel(from: hourStart, to: nextHour)
            let isOngoing = (hourStart == currentHourStart)
            var payload: [String: String] = [
                "kcal": String(format: "%.0f", totalKcal),
                "hourLabel": hourLabel,
                "source": source,
            ]
            if isOngoing {
                payload["ongoing"] = "true"
            }
            return SensingEvent(timestamp: hourStart, modality: modality, payload: payload)
        }
    }

    /// Format an hour range like "9-10AM" or "12-1PM".
    private static func hourRangeLabel(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Check if both hours share the same AM/PM
        let startHour = Calendar.current.component(.hour, from: start)
        let endHour = Calendar.current.component(.hour, from: end)
        let startIsAM = startHour < 12
        let endIsAM = endHour < 12

        if startIsAM == endIsAM {
            // Same period: "9-10AM"
            formatter.dateFormat = "h"
            let s = formatter.string(from: start)
            formatter.dateFormat = "ha"
            let e = formatter.string(from: end)
            return "\(s)-\(e)"
        } else {
            // Cross period: "11AM-12PM"
            formatter.dateFormat = "ha"
            let s = formatter.string(from: start)
            let e = formatter.string(from: end)
            return "\(s)-\(e)"
        }
    }

    /// Resume the audio stream sensor if it was enabled but died during background suspension.
    /// Called when the app returns to the foreground.
    func resumeAudioStreamIfNeeded() {
        engine.resumeAudioStreamIfNeeded()
    }

    /// Check for new photos taken while the app was in the background.
    func checkForNewPhotos() {
        engine.checkForNewPhotos()
    }

    // MARK: - Storage Keys

    private enum StorageKeys {
        static let sensingEnabled = "ryanhub_bobo_sensing_enabled"
        static let narrations = "ryanhub_bobo_narrations"
        static let nudges = "ryanhub_bobo_nudges"
        static let lastNudgeGeneration = "ryanhub_bobo_last_nudge_generation"
    }
}

// MARK: - Narration Network Response Models

/// Response from the audio upload endpoint.
private struct NarrationAudioUploadResponse: Decodable {
    let ok: Bool
    let filename: String
    let size: Int
}

/// Response from the narration analysis endpoint.
private struct NarrationAnalysisResponse: Decodable {
    let transcript: String?
    let affect: AffectAnalysis?
}

/// Internal result combining transcript and affect analysis.
private struct NarrationAnalysisResult {
    let transcript: String
    let affect: AffectAnalysis?
}

// MARK: - Nudge Analysis Response Models

/// Response from the nudge analysis endpoint.
private struct NudgeAnalysisResponse: Decodable {
    let nudges: [NudgeData]
}

/// Individual nudge data from the server analysis response.
private struct NudgeData: Decodable {
    let content: String
    let type: String
    let trigger: String?
    let priority: String?
    let relatedModalities: [String]?
}
