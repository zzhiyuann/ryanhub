import Foundation

// MARK: - Sensing Engine

/// Main coordinator for the POPO sensing system.
/// Manages the lifecycle of all individual sensors, collects their events,
/// stores them locally, and coordinates periodic sync to the bridge server.
@MainActor
@Observable
final class SensingEngine {
    // MARK: - Observable State

    /// Whether the sensing engine is actively collecting data.
    var isRunning: Bool = false

    /// Timestamp of the last successful sync to the server.
    var lastSyncTime: Date?

    /// Most recent events for UI display (capped at 100).
    var recentEvents: [SensingEvent] = []

    /// Number of events pending sync.
    var pendingEventCount: Int = 0

    // MARK: - Sensors

    private let motionSensor = MotionSensor()
    private let healthSensor = HealthSensor()
    private let locationSensor = LocationSensor()
    private let screenSensor = ScreenSensor()

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

    /// Maximum events to display in UI.
    private static let maxRecentEvents = 100

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

        // Start all sensors
        motionSensor.start()
        healthSensor.start()
        locationSensor.start()
        screenSensor.start()

        // Load existing events from store
        recentEvents = Array(dataStore.recentEvents(hours: 24).prefix(Self.maxRecentEvents))
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

        syncTimer?.invalidate()
        syncTimer = nil

        print("[SensingEngine] Stopped all sensors")
    }

    // MARK: - Event Recording

    /// Called by each sensor when new data arrives.
    /// Stores the event locally and triggers sync if batch threshold is reached.
    func recordEvent(_ event: SensingEvent) {
        // Add to UI display list (keep newest first, capped)
        recentEvents.insert(event, at: 0)
        if recentEvents.count > Self.maxRecentEvents {
            recentEvents = Array(recentEvents.prefix(Self.maxRecentEvents))
        }

        // Persist to local store
        dataStore.save(event)
        pendingEventCount = dataStore.pendingCount

        // Trigger immediate sync if batch threshold reached
        if pendingEventCount >= Self.batchSizeThreshold {
            Task { await syncPendingEvents() }
        }
    }

    // MARK: - Sync

    /// Sync all pending events to the bridge server.
    func syncPendingEvents() async {
        let pending = dataStore.pendingEvents()
        guard !pending.isEmpty else { return }

        let syncedIDs = await syncService.syncEvents(pending)
        if !syncedIDs.isEmpty {
            dataStore.markSynced(syncedIDs)
            lastSyncTime = Date()
            pendingEventCount = dataStore.pendingCount
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
}
