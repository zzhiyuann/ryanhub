import Foundation
import CoreMotion

// MARK: - Sensing Engine

/// Main coordinator for the POPO sensing system.
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
                UserDefaults.standard.set(time.timeIntervalSince1970, forKey: "ryanhub_popo_last_sync_time")
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

    // MARK: - Services

    private let syncService = PopoSyncService()
    private let dataStore = PopoDataStore()

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
        wifiSensor.onEvent = { [weak self] event in
            Task { @MainActor in self?.recordEvent(event) }
        }
        bluetoothSensor.onEvent = { [weak self] event in
            Task { @MainActor in self?.recordEvent(event) }
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

        // Restore last sync time from disk
        let savedSyncTime = UserDefaults.standard.double(forKey: "ryanhub_popo_last_sync_time")
        if savedSyncTime > 0 {
            lastSyncTime = Date(timeIntervalSince1970: savedSyncTime)
        }

        // Load all events for today from store
        recentEvents = dataStore.events(for: Date())
        pendingEventCount = dataStore.pendingCount

        // Start periodic sync timer
        startSyncTimer()

        print("[SensingEngine] Started all sensors")
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

        syncTimer?.invalidate()
        syncTimer = nil

        print("[SensingEngine] Stopped all sensors")
    }

    // MARK: - Audio Stream (Independent Toggle)

    /// Whether the audio stream sensor is actively recording.
    /// This sensor is independent from the main sensing toggle due to
    /// battery and privacy concerns — it requires explicit user opt-in.
    var isAudioStreamEnabled = false

    /// Start the audio stream sensor independently of the main sensing toggle.
    func startAudioStream() {
        guard !isAudioStreamEnabled else { return }
        isAudioStreamEnabled = true
        audioStreamSensor.onEvent = { [weak self] event in
            Task { @MainActor in self?.recordEvent(event) }
        }
        audioStreamSensor.start()
        print("[SensingEngine] Audio stream started")
    }

    /// Stop the audio stream sensor.
    func stopAudioStream() {
        guard isAudioStreamEnabled else { return }
        isAudioStreamEnabled = false
        audioStreamSensor.stop()
        print("[SensingEngine] Audio stream stopped")
    }

    /// Resume the audio stream sensor if it was enabled but the connection/engine died.
    /// Called on foreground resume to recover from iOS background suspension.
    func resumeAudioStreamIfNeeded() {
        guard isAudioStreamEnabled else { return }
        audioStreamSensor.resumeIfNeeded()
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

        // Add to UI display list (newest first)
        recentEvents.insert(event, at: 0)

        // Persist to local store
        dataStore.save(event)
        pendingEventCount = dataStore.pendingCount

        // Trigger immediate sync if batch threshold reached
        if pendingEventCount >= Self.batchSizeThreshold {
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
        queue.name = "com.ryanhub.popo.background-motion"
        queue.maxConcurrentOperationCount = 1

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            activityManager.queryActivityStarting(from: start, to: end, to: queue) { [weak self] activities, error in
                if let activities {
                    for activity in activities {
                        let activityType: String
                        if activity.walking { activityType = "walking" }
                        else if activity.running { activityType = "running" }
                        else if activity.cycling { activityType = "cycling" }
                        else if activity.automotive { activityType = "automotive" }
                        else if activity.stationary { activityType = "stationary" }
                        else { activityType = "unknown" }

                        let confidence: String
                        switch activity.confidence {
                        case .low: confidence = "low"
                        case .medium: confidence = "medium"
                        case .high: confidence = "high"
                        @unknown default: confidence = "unknown"
                        }

                        let event = SensingEvent(
                            timestamp: activity.startDate,
                            modality: .motion,
                            payload: [
                                "activityType": activityType,
                                "confidence": confidence,
                                "source": "background_backfill"
                            ]
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
