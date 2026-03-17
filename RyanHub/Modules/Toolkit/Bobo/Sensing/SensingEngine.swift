import Foundation
import CoreMotion
import UIKit

// MARK: - Sensing Engine

/// Main coordinator for the BOBO sensing system.
/// Manages the lifecycle of all individual sensors, collects their events,
/// stores them locally, and coordinates periodic sync to the bridge server.
@MainActor
@Observable
final class SensingEngine {
    // MARK: - Singleton

    /// Shared instance for access from BGTaskScheduler and other system callbacks.
    static let shared = SensingEngine()

    // MARK: - Observable State

    /// Whether the sensing engine is actively collecting data.
    var isRunning: Bool = false

    /// Timestamp of the last successful sync to the server.
    var lastSyncTime: Date? {
        didSet {
            if let time = lastSyncTime {
                UserDefaults.standard.set(time.timeIntervalSince1970, forKey: "ryanhub_bobo_last_sync_time")
            }
        }
    }

    /// Most recent events for UI display (capped at 100).
    var recentEvents: [SensingEvent] = []

    /// Number of events pending sync.
    var pendingEventCount: Int = 0

    /// Whether a sync operation is currently in progress.
    var isSyncing: Bool = false

    /// Error message from the last failed sync attempt (nil if last sync succeeded).
    var lastSyncError: String?

    // MARK: - Sensors

    private let motionSensor = MotionSensor()
    private let healthSensor = HealthSensor()
    private let locationSensor = LocationSensor()
    private let screenSensor = ScreenSensor()
    private let batterySensor = BatterySensor()
    private let callSensor = CallSensor()
    private let wifiSensor = WiFiSensor()
    private let bluetoothSensor = BluetoothSensor()
    private let audioStreamSensor = AudioStreamSensor()
    private let photoLibrarySensor = PhotoLibrarySensor()

    // MARK: - Services

    private let syncService = BoboSyncService()
    private let dataStore = BoboDataStore()

    // MARK: - Internal State

    /// Timer for periodic sync.
    private var syncTimer: Timer?

    /// Sync interval in seconds (5 minutes).
    private static let syncInterval: TimeInterval = 300

    /// Batch size threshold that triggers an immediate sync.
    private static let batchSizeThreshold = 50

    /// Maximum events to keep in the UI display list.
    private static let maxRecentEvents = 500

    // MARK: - Lifecycle

    /// Start all sensors and begin collecting data.
    func startSensing() {
        guard !isRunning else { return }
        isRunning = true

        // Wire up sensor callbacks
        motionSensor.onEvent = { [weak self] event in
            Task { @MainActor in self?.recordEvent(event) }
        }
        healthSensor.onEvent = { [weak self] event in
            Task { @MainActor in self?.recordEvent(event) }
        }
        locationSensor.onEvent = { [weak self] event in
            Task { @MainActor in self?.recordEvent(event) }
        }
        screenSensor.onEvent = { [weak self] event in
            Task { @MainActor in self?.recordEvent(event) }
        }
        batterySensor.onEvent = { [weak self] event in
            Task { @MainActor in self?.recordEvent(event) }
        }
        callSensor.onEvent = { [weak self] event in
            Task { @MainActor in self?.recordEvent(event) }
        }
        callSensor.onUpdateEvent = { [weak self] eventID, payload in
            Task { @MainActor in self?.enrichCallEvent(id: eventID, merge: payload) }
        }
        wifiSensor.onEvent = { [weak self] event in
            Task { @MainActor in self?.recordEvent(event) }
        }
        bluetoothSensor.onEvent = { [weak self] event in
            Task { @MainActor in self?.recordEvent(event) }
        }
        photoLibrarySensor.onEvent = { [weak self] event in
            Task { @MainActor in self?.recordEvent(event) }
        }
        photoLibrarySensor.onLibraryChange = {
            Task { @MainActor in
                RBMetaMediaImporter.shared.importNewMedia()
            }
        }

        // Start all sensors
        motionSensor.start()
        healthSensor.start()
        locationSensor.start()
        screenSensor.start()
        batterySensor.start()
        callSensor.start()
        wifiSensor.start()
        bluetoothSensor.start()
        photoLibrarySensor.start()

        // Restore last sync time from disk
        let savedSyncTime = UserDefaults.standard.double(forKey: "ryanhub_bobo_last_sync_time")
        if savedSyncTime > 0 {
            lastSyncTime = Date(timeIntervalSince1970: savedSyncTime)
        }

        // Load all events for today from store
        recentEvents = dataStore.events(for: Date())
        pendingEventCount = dataStore.pendingCount

        // Start periodic sync timer
        startSyncTimer()

        print("[SensingEngine] Started all sensors — loaded \(recentEvents.count) events for today, \(pendingEventCount) pending sync")

        // Import any RB Meta media from the last 7 days that hasn't been processed yet
        RBMetaMediaImporter.shared.importNewMedia()

        // Backfill motion data from CoreMotion to recover any gaps
        // (e.g., events lost to decode failure, or app was killed for a while)
        let startOfDay = Calendar.current.startOfDay(for: Date())
        Task {
            await backfillMotionActivity(from: startOfDay, to: Date())
        }
    }

    /// Stop all sensors and cancel the sync timer.
    func stopSensing() {
        guard isRunning else { return }
        isRunning = false

        motionSensor.stop()
        healthSensor.stop()
        locationSensor.stop()
        screenSensor.stop()
        batterySensor.stop()
        callSensor.stop()
        wifiSensor.stop()
        bluetoothSensor.stop()
        photoLibrarySensor.stop()

        syncTimer?.invalidate()
        syncTimer = nil

        print("[SensingEngine] Stopped all sensors")
    }

    // MARK: - Audio Stream (Independent Toggle)

    /// Whether the audio stream sensor is actively recording.
    /// This sensor is independent from the main sensing toggle due to
    /// battery and privacy concerns — it requires explicit user opt-in.
    var isAudioStreamEnabled = false

    /// Whether audio is currently coming from the Apple Watch mic.
    var isUsingWatchMic: Bool {
        isAudioStreamEnabled && audioStreamSensor.currentSource == .watch
    }

    /// Start the audio stream sensor independently of the main sensing toggle.
    /// Always starts local mic first (reliable), then attempts to activate Watch mic.
    /// If Watch responds with audio data, automatically switches from local to Watch.
    func startAudioStream() {
        guard !isAudioStreamEnabled else { return }
        isAudioStreamEnabled = true
        audioStreamSensor.onEvent = { [weak self] event in
            Task { @MainActor in self?.recordEvent(event) }
        }

        // Always observe Watch reachability changes while audio is enabled
        observeWatchReachability()

        // Always start local mic first (immediate, reliable)
        audioStreamSensor.start()
        print("[SensingEngine] Audio stream started (local mic)")

        // Also try to activate Watch mic — if it responds, we'll switch over
        attemptWatchMicActivation()
    }

    /// Stop the audio stream sensor.
    func stopAudioStream() {
        guard isAudioStreamEnabled else { return }
        isAudioStreamEnabled = false

        // If Watch was streaming, stop it
        let watchManager = WatchSessionManager.shared
        if watchManager.isWatchStreaming {
            watchManager.stopWatchAudio()
            watchManager.onAudioData = nil
        }

        audioStreamSensor.stop()
        removeWatchObservers()
        print("[SensingEngine] Audio stream stopped")
    }

    /// Resume the audio stream sensor if it was enabled but the connection/engine died.
    /// Called on foreground resume to recover from iOS background suspension.
    func resumeAudioStreamIfNeeded() {
        guard isAudioStreamEnabled else { return }

        if audioStreamSensor.currentSource == .local {
            // Resume local mic and re-attempt Watch activation
            audioStreamSensor.resumeIfNeeded()
            attemptWatchMicActivation()
        } else if audioStreamSensor.currentSource == .watch {
            // If Watch stopped sending data, the source would have already
            // been switched via handleWatchDisconnect. If we're still on
            // Watch here, just re-attempt in case connection recovered.
            attemptWatchMicActivation()
        }
    }

    // MARK: - Watch Audio Helpers

    /// Try to send start command to Watch. If Watch responds with audio data,
    /// automatically switch from local mic to Watch mic.
    private func attemptWatchMicActivation() {
        let watchManager = WatchSessionManager.shared

        // Wire up the audio data callback — when first data arrives, switch source
        watchManager.onAudioData = { [weak self] data in
            guard let self else { return }
            if self.audioStreamSensor.currentSource == .local {
                // First audio from Watch — switch from local to Watch
                print("[SensingEngine] Received Watch audio data — switching from local to Watch mic")
                self.audioStreamSensor.switchToExternalSource()
            }
            self.audioStreamSensor.feedExternalAudio(data)
        }

        // Try to send start command (may fail if not reachable — that's OK)
        watchManager.startWatchAudio()
    }

    /// Handle Watch disconnect during active streaming — auto-fallback to local mic.
    private func handleWatchDisconnect() {
        guard isAudioStreamEnabled, audioStreamSensor.currentSource == .watch else { return }
        print("[SensingEngine] Watch disconnected — falling back to local mic")
        WatchSessionManager.shared.onAudioData = nil
        audioStreamSensor.switchToLocalSource()
    }

    /// Handle Watch becoming reachable — try to activate Watch mic if we're on local.
    private func handleWatchBecameReachable() {
        guard isAudioStreamEnabled else { return }
        // Re-attempt Watch activation — if Watch starts streaming, the
        // onAudioData callback will auto-switch from local to Watch.
        attemptWatchMicActivation()
    }

    /// Start observing Watch reachability notifications.
    private func observeWatchReachability() {
        NotificationCenter.default.addObserver(
            forName: .watchAudioStreamDidStop,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWatchDisconnect()
        }
        NotificationCenter.default.addObserver(
            forName: .watchDidBecomeReachable,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWatchBecameReachable()
        }
    }

    /// Remove all Watch reachability observers.
    private func removeWatchObservers() {
        NotificationCenter.default.removeObserver(self, name: .watchAudioStreamDidStop, object: nil)
        NotificationCenter.default.removeObserver(self, name: .watchDidBecomeReachable, object: nil)
    }

    /// Resume the health sensor on foreground return. Re-fetches all HealthKit data
    /// from the last fetch timestamp to now, filling any gaps from background suspension.
    func resumeHealthSensor() {
        guard isRunning else { return }
        healthSensor.resume()
    }

    /// Check for new photos taken while the app was in the background.
    func checkForNewPhotos() {
        // Always trigger RB Meta importer, even when sensing is toggled off.
        // Users may import media while BOBO sensing is paused.
        if isRunning {
            photoLibrarySensor.checkNow()
        }
        RBMetaMediaImporter.shared.importNewMedia()
    }

    // MARK: - Event Recording

    /// Called by each sensor when new data arrives.
    /// Stores the event locally and triggers sync if batch threshold is reached.
    ///
    /// For screen "off" events, instead of just storing the event, we also enrich
    /// the most recent screen "on" event with the `onDuration` so the timeline
    /// shows how long the screen was on in a single consolidated row.
    ///
    /// For audio "speaker_update" events, the matching transcript event is enriched
    /// with speaker info instead of creating a new timeline row.
    func recordEvent(_ event: SensingEvent) {
        print("[SensingEngine] recordEvent: modality=\(event.modality), payload=\(event.payload.keys.sorted())")
        // Screen off events enrich the previous screen on event
        if event.modality == .screen, event.payload["state"] == "off",
           let onDuration = event.payload["onDuration"] {
            enrichLastScreenOnEvent(onDuration: onDuration)
        }

        // Audio speaker_update events enrich the matching transcript event
        if event.modality == .audio, event.payload["status"] == "speaker_update",
           let segmentId = event.payload["segmentId"] {
            enrichAudioTranscript(
                segmentId: segmentId,
                speaker: event.payload["speaker"] ?? "unknown",
                confidence: event.payload["confidence"] ?? "0"
            )
            return  // Don't create a new timeline row
        }

        // Motion events: enrich the previous episode with duration and nextActivity.
        // Skip for backfill events — they already come pre-enriched with duration/nextActivity.
        if event.modality == .motion, let newActivity = event.payload["activityType"],
           event.payload["source"] != "background_backfill" {
            enrichLastMotionEpisode(nextActivity: newActivity, transitionTime: event.timestamp)
        }

        // Deduplicate backfill motion events — skip if a motion event with
        // the same activity type exists within 60 seconds of this timestamp
        if event.modality == .motion, event.payload["source"] == "background_backfill" {
            let ts = event.timestamp
            let activity = event.payload["activityType"] ?? ""
            let isDuplicate = recentEvents.contains { existing in
                existing.modality == .motion
                    && existing.payload["activityType"] == activity
                    && abs(existing.timestamp.timeIntervalSince(ts)) < 60
            }
            if isDuplicate {
                return
            }
        }

        // Add to UI display list (newest first)
        recentEvents.insert(event, at: 0)

        // Persist to local store
        dataStore.save(event)
        pendingEventCount = dataStore.pendingCount

        // Trigger immediate sync if batch threshold reached, or if app is
        // in background (so HealthKit observer wake-ups push data to bridge
        // immediately instead of waiting for 50 events).
        let isBackground = UIApplication.shared.applicationState != .active
        if pendingEventCount >= (isBackground ? 1 : Self.batchSizeThreshold) {
            Task { await syncPendingEvents() }
        }
    }

    /// Find the most recent screen "on" event and add `onDuration` to its payload.
    private func enrichLastScreenOnEvent(onDuration: String) {
        // Update in-memory recentEvents array
        if let index = recentEvents.firstIndex(where: {
            $0.modality == .screen && $0.payload["state"] == "on"
        }) {
            recentEvents[index].payload["onDuration"] = onDuration
            // Also update in the persisted data store
            dataStore.updateEventPayload(id: recentEvents[index].id, merge: ["onDuration": onDuration])
        }
    }

    /// Find the most recent motion event and add `duration` and `nextActivity` to close the episode.
    private func enrichLastMotionEpisode(nextActivity: String, transitionTime: Date) {
        if let index = recentEvents.firstIndex(where: { $0.modality == .motion }) {
            let episodeStart = recentEvents[index].timestamp
            let duration = transitionTime.timeIntervalSince(episodeStart)
            let durationStr = String(format: "%.0f", duration)
            let merge = ["duration": durationStr, "nextActivity": nextActivity]
            recentEvents[index].payload.merge(merge) { _, new in new }
            dataStore.updateEventPayload(id: recentEvents[index].id, merge: merge)
        }
    }

    /// Enrich a call event by ID (e.g., add duration after hangup).
    private func enrichCallEvent(id: UUID, merge payload: [String: String]) {
        if let index = recentEvents.firstIndex(where: { $0.id == id }) {
            recentEvents[index].payload.merge(payload) { _, new in new }
            dataStore.updateEventPayload(id: id, merge: payload)
        }
    }

    /// Find the audio transcript event matching `segmentId` and merge speaker info.
    private func enrichAudioTranscript(segmentId: String, speaker: String, confidence: String) {
        if let index = recentEvents.firstIndex(where: {
            $0.modality == .audio
                && $0.payload["status"] == "transcript"
                && $0.payload["segmentId"] == segmentId
        }) {
            recentEvents[index].payload["speaker"] = speaker
            recentEvents[index].payload["confidence"] = confidence
            // Also update in the persisted data store
            dataStore.updateEventPayload(
                id: recentEvents[index].id,
                merge: ["speaker": speaker, "confidence": confidence]
            )
        }
    }

    /// Reclassify a previously ingested media event by asset identifier.
    /// Used when RBMeta importer obtains stronger attribution than initial
    /// PhotoLibrarySensor classification.
    @discardableResult
    func reclassifyMediaEvent(assetId: String, merge payload: [String: String]) -> Bool {
        guard let updatedID = dataStore.updateLatestEventPayload(assetId: assetId, merge: payload) else {
            return false
        }
        if let index = recentEvents.firstIndex(where: { $0.id == updatedID }) {
            recentEvents[index].payload.merge(payload) { _, new in new }
        }
        return true
    }

    // MARK: - Sync

    /// Sync all pending events to the bridge server.
    func syncPendingEvents() async {
        let pending = dataStore.pendingEvents()
        guard !pending.isEmpty else {
            // Nothing to sync — still counts as a successful "check"
            lastSyncError = nil
            return
        }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        let syncedIDs = await syncService.syncEvents(pending)
        if !syncedIDs.isEmpty {
            dataStore.markSynced(syncedIDs)
            lastSyncTime = Date()
            pendingEventCount = dataStore.pendingCount
            lastSyncError = nil
            print("[SensingEngine] Sync succeeded: \(syncedIDs.count) events synced")
        } else {
            lastSyncError = "Sync failed — server unreachable or returned error"
            print("[SensingEngine] Sync failed for \(pending.count) events")
        }
    }

    /// Start a repeating timer for periodic sync.
    private func startSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: Self.syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncPendingEvents()
            }
        }
    }

    // MARK: - Convenience

    /// Return persisted events for a specific date from the data store.
    /// Used by the ViewModel to display phone sensing data for past dates.
    func storedEvents(for date: Date) -> [SensingEvent] {
        dataStore.events(for: date)
    }

    /// Delete a stored sensing event from local cache and current UI state.
    @discardableResult
    func deleteStoredEvent(id: UUID) -> Bool {
        let deleted = dataStore.deleteEvent(id: id)
        guard deleted else { return false }

        recentEvents.removeAll { $0.id == id }
        pendingEventCount = dataStore.pendingCount
        return true
    }

    /// Return events filtered by modality.
    func events(for modality: SensingModality) -> [SensingEvent] {
        recentEvents.filter { $0.modality == modality }
    }

    /// Return a summary of recent sensing activity per modality.
    var modalitySummary: [(modality: SensingModality, count: Int, latest: Date?)] {
        SensingModality.allCases.map { modality in
            let modalityEvents = events(for: modality)
            return (
                modality: modality,
                count: modalityEvents.count,
                latest: modalityEvents.first?.timestamp
            )
        }
        .filter { $0.count > 0 }
    }

    // MARK: - Background Wake

    /// Called from BGTaskScheduler when the app wakes in the background.
    /// Backfills any missed motion/pedometer data, takes snapshots of battery/wifi/bluetooth,
    /// and syncs pending events.
    func handleBackgroundWake() async {
        print("[SensingEngine] Background wake — backfilling data, taking snapshots, and syncing")

        // Determine the backfill window: from last sync (or 1 hour ago) to now
        let now = Date()
        let backfillStart = lastSyncTime ?? now.addingTimeInterval(-3600)

        // Backfill pedometer data
        await backfillPedometerData(from: backfillStart, to: now)

        // Backfill motion activity data
        await backfillMotionActivity(from: backfillStart, to: now)

        // Take one-shot snapshots of ambient sensors during background execution
        batterySensor.checkNow()
        wifiSensor.checkNow()
        bluetoothSensor.quickScan(duration: 5)

        // Small delay to let the BT quick scan complete before syncing
        try? await Task.sleep(nanoseconds: 6_000_000_000)

        // Sync all pending events to the server
        await syncPendingEvents()

        print("[SensingEngine] Background wake completed")
    }

    /// Query CMPedometer for step data in the given range and record events.
    private func backfillPedometerData(from start: Date, to end: Date) async {
        guard CMPedometer.isStepCountingAvailable() else { return }

        let pedometer = CMPedometer()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            pedometer.queryPedometerData(from: start, to: end) { [weak self] data, error in
                if let data {
                    let event = SensingEvent(
                        modality: .steps,
                        payload: [
                            "steps": "\(data.numberOfSteps)",
                            "source": "background_backfill",
                            "distance": data.distance.map { "\($0)" } ?? "unknown"
                        ]
                    )
                    Task { @MainActor in
                        self?.recordEvent(event)
                    }
                } else if let error {
                    print("[SensingEngine] Pedometer backfill error: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
    }

    /// Query CMMotionActivityManager for activity data in the given range and record events.
    private func backfillMotionActivity(from start: Date, to end: Date) async {
        guard CMMotionActivityManager.isActivityAvailable() else { return }

        let activityManager = CMMotionActivityManager()
        let queue = OperationQueue()
        queue.name = "com.ryanhub.bobo.background-motion"
        queue.maxConcurrentOperationCount = 1

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            activityManager.queryActivityStarting(from: start, to: end, to: queue) { [weak self] activities, error in
                if let activities {
                    // Build episode-based transitions: filter to meaningful state changes,
                    // then enrich each episode with duration and nextActivity.
                    struct Episode {
                        let activityType: String
                        let confidence: String
                        let startDate: Date
                    }

                    // Pass 1: collect transitions (skip unknown + low confidence)
                    var transitions: [Episode] = []
                    var lastType: String?
                    for activity in activities {
                        let activityType: String
                        if activity.walking { activityType = "walking" }
                        else if activity.running { activityType = "running" }
                        else if activity.cycling { activityType = "cycling" }
                        else if activity.automotive { activityType = "automotive" }
                        else if activity.stationary { activityType = "stationary" }
                        else { continue }

                        guard activity.confidence != .low else { continue }
                        guard activityType != lastType else { continue }

                        let confidence: String
                        switch activity.confidence {
                        case .medium: confidence = "medium"
                        case .high: confidence = "high"
                        default: confidence = "unknown"
                        }

                        transitions.append(Episode(activityType: activityType, confidence: confidence, startDate: activity.startDate))
                        lastType = activityType
                    }

                    // Pass 2: emit episodes with duration and nextActivity from the following transition
                    for (i, ep) in transitions.enumerated() {
                        var payload: [String: String] = [
                            "activityType": ep.activityType,
                            "confidence": ep.confidence,
                            "source": "background_backfill"
                        ]
                        if i + 1 < transitions.count {
                            let next = transitions[i + 1]
                            let duration = next.startDate.timeIntervalSince(ep.startDate)
                            payload["duration"] = String(format: "%.0f", duration)
                            payload["nextActivity"] = next.activityType
                        }
                        let event = SensingEvent(
                            timestamp: ep.startDate,
                            modality: .motion,
                            payload: payload
                        )
                        Task { @MainActor in
                            self?.recordEvent(event)
                        }
                    }
                } else if let error {
                    print("[SensingEngine] Motion backfill error: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
    }
}
