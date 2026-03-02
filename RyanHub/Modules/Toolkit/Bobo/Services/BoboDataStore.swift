import Foundation

// MARK: - BOBO Data Store

/// Local file-based cache for sensing events that handles persistence and sync state.
/// Stores ALL events permanently on disk (never pruned by age), keeps them
/// in memory for quick access, and clears synced events after successful POST.
final class BoboDataStore {
    /// All events currently in the store (both synced and pending).
    private(set) var events: [SensingEvent] = []

    /// IDs of events that have been successfully synced to the server.
    private var syncedEventIDs: Set<UUID> = []

    /// File path for persisting pending events.
    private let eventsFilePath: URL

    /// File path for persisting synced event IDs.
    private let syncedIDsFilePath: URL

    /// Maximum number of events to keep in memory (oldest are persisted on disk).
    private static let maxInMemoryCount: Int = 2000

    // MARK: - Init

    init() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let boboDir = documentsDir.appendingPathComponent("bobo", isDirectory: true)
        let popoDir = documentsDir.appendingPathComponent("popo", isDirectory: true)

        // Migrate data from old "popo" directory if it exists and "bobo" doesn't
        let fm = FileManager.default
        if fm.fileExists(atPath: popoDir.path) && !fm.fileExists(atPath: boboDir.path) {
            do {
                try fm.moveItem(at: popoDir, to: boboDir)
                // Rename data files inside
                let oldEvents = boboDir.appendingPathComponent("popo_events.json")
                let newEvents = boboDir.appendingPathComponent("bobo_events.json")
                if fm.fileExists(atPath: oldEvents.path) {
                    try fm.moveItem(at: oldEvents, to: newEvents)
                }
                let oldSynced = boboDir.appendingPathComponent("popo_synced_ids.json")
                let newSynced = boboDir.appendingPathComponent("bobo_synced_ids.json")
                if fm.fileExists(atPath: oldSynced.path) {
                    try fm.moveItem(at: oldSynced, to: newSynced)
                }
                print("[BoboDataStore] Migrated popo/ → bobo/ directory")
            } catch {
                print("[BoboDataStore] Migration failed: \(error.localizedDescription)")
            }
        }

        // Ensure the directory exists
        try? fm.createDirectory(at: boboDir, withIntermediateDirectories: true)

        self.eventsFilePath = boboDir.appendingPathComponent("bobo_events.json")
        self.syncedIDsFilePath = boboDir.appendingPathComponent("bobo_synced_ids.json")

        loadFromDisk()
        migrateMotionToEpisodes()
        print("[BoboDataStore] Loaded \(events.count) events from disk")
    }

    // MARK: - Public API

    /// Save a new sensing event to the store.
    func save(_ event: SensingEvent) {
        events.append(event)
        trimInMemoryIfNeeded()
        persistToDisk()
    }

    /// Save a batch of events to the store.
    func save(_ newEvents: [SensingEvent]) {
        events.append(contentsOf: newEvents)
        trimInMemoryIfNeeded()
        persistToDisk()
    }

    /// Return all events that have not yet been synced to the server.
    func pendingEvents() -> [SensingEvent] {
        events.filter { !syncedEventIDs.contains($0.id) }
    }

    /// Mark a batch of events as successfully synced.
    func markSynced(_ eventIDs: [UUID]) {
        syncedEventIDs.formUnion(eventIDs)
        persistSyncedIDs()
    }

    /// Update an existing event's payload by ID. Used to enrich screen "on" events
    /// with on-duration when the corresponding "off" event arrives.
    func updateEventPayload(id: UUID, merge newPayload: [String: String]) {
        if let index = events.firstIndex(where: { $0.id == id }) {
            for (key, value) in newPayload {
                events[index].payload[key] = value
            }
            persistToDisk()
        }
    }

    /// Return all events for a given date (full 24-hour day).
    func events(for date: Date) -> [SensingEvent] {
        let calendar = Calendar.current
        return events.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Return all events from the last N hours (convenience).
    func recentEvents(hours: Int = 24) -> [SensingEvent] {
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        return events.filter { $0.timestamp > cutoff }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Return the count of pending (unsynced) events.
    var pendingCount: Int {
        events.count - syncedEventIDs.intersection(events.map(\.id)).count
    }

    // MARK: - Migration

    /// One-time migration: remove unknown motion events, merge consecutive same-activity
    /// episodes, and rebuild episode data (duration + nextActivity).
    private func migrateMotionToEpisodes() {
        let migrationKey = "ryanhub_bobo_motion_episode_migration_v3"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        // Step 1: Remove unknown motion events
        events.removeAll { $0.modality == .motion && ($0.payload["activityType"] ?? "unknown") == "unknown" }

        // Step 2: Merge consecutive motion events with the same activityType.
        // Keep the first one (earliest timestamp), remove duplicates that follow.
        let motionIDs = events.indices
            .filter { events[$0].modality == .motion }
            .sorted { events[$0].timestamp < events[$1].timestamp }

        var idsToRemove: Set<UUID> = []
        for (i, idx) in motionIDs.enumerated() {
            guard i + 1 < motionIDs.count else { break }
            let nextIdx = motionIDs[i + 1]
            if events[idx].payload["activityType"] == events[nextIdx].payload["activityType"] {
                // Next is same activity — mark it for removal (keep the earlier one)
                idsToRemove.insert(events[nextIdx].id)
            }
        }
        if !idsToRemove.isEmpty {
            events.removeAll { idsToRemove.contains($0.id) }
        }

        // Step 3: Rebuild episode data on the deduplicated motion events
        let finalMotionIndices = events.indices
            .filter { events[$0].modality == .motion }
            .sorted { events[$0].timestamp < events[$1].timestamp }

        for (i, idx) in finalMotionIndices.enumerated() {
            // Clean up old fields
            events[idx].payload.removeValue(forKey: "previousActivity")
            events[idx].payload.removeValue(forKey: "previousDuration")
            events[idx].payload.removeValue(forKey: "transitionType")

            if i + 1 < finalMotionIndices.count {
                let nextIdx = finalMotionIndices[i + 1]
                let duration = events[nextIdx].timestamp.timeIntervalSince(events[idx].timestamp)
                events[idx].payload["duration"] = String(format: "%.0f", duration)
                events[idx].payload["nextActivity"] = events[nextIdx].payload["activityType"] ?? "unknown"
            } else {
                events[idx].payload.removeValue(forKey: "duration")
                events[idx].payload.removeValue(forKey: "nextActivity")
            }
        }

        persistToDisk()
        print("[BoboDataStore] Motion migration v3: \(idsToRemove.count) duplicates merged, \(finalMotionIndices.count) episodes rebuilt")
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    // MARK: - Persistence

    /// Load events and synced IDs from disk.
    private func loadFromDisk() {
        // Load events
        if let data = try? Data(contentsOf: eventsFilePath) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            events = (try? decoder.decode([SensingEvent].self, from: data)) ?? []
        }

        // Load synced IDs
        if let data = try? Data(contentsOf: syncedIDsFilePath) {
            let decoder = JSONDecoder()
            syncedEventIDs = (try? decoder.decode(Set<UUID>.self, from: data)) ?? []
        }

        // Clean up stale data on load
        trimInMemoryIfNeeded()
    }

    /// Persist current events to disk.
    private func persistToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(events) {
            try? data.write(to: eventsFilePath, options: .atomic)
        }
    }

    /// Persist synced event IDs to disk.
    private func persistSyncedIDs() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(syncedEventIDs) {
            try? data.write(to: syncedIDsFilePath, options: .atomic)
        }
    }

    /// Trim in-memory events if exceeding cap (keep newest). All events remain on disk.
    private func trimInMemoryIfNeeded() {
        if events.count > Self.maxInMemoryCount {
            events.sort { $0.timestamp > $1.timestamp }
            let trimmed = Array(events.prefix(Self.maxInMemoryCount))
            // Persist ALL events to disk before trimming memory
            persistToDisk()
            events = trimmed
        }

        // Clean up synced IDs for events no longer in memory
        let currentIDs = Set(events.map(\.id))
        syncedEventIDs = syncedEventIDs.intersection(currentIDs)
    }
}
