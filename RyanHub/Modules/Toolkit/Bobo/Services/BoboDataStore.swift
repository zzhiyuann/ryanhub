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

    /// Maximum number of events to keep in memory.
    private static let maxInMemoryCount: Int = 10_000

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
        trimOldSyncedFromDisk()

        // Diagnostic: count events per modality
        var modalityCounts: [String: Int] = [:]
        for event in events {
            modalityCounts[event.modality.rawValue, default: 0] += 1
        }
        print("[BoboDataStore] Loaded \(events.count) events — \(modalityCounts)")
    }

    // MARK: - Public API

    /// Save a new sensing event to the store.
    func save(_ event: SensingEvent) {
        events.append(event)
        persistToDisk()
        trimInMemoryOnly()
    }

    /// Save a batch of events to the store.
    func save(_ newEvents: [SensingEvent]) {
        events.append(contentsOf: newEvents)
        persistToDisk()
        trimInMemoryOnly()
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

    /// Delete a specific event from the local store and synced-id cache.
    @discardableResult
    func deleteEvent(id: UUID) -> Bool {
        let originalCount = events.count
        events.removeAll { $0.id == id }
        syncedEventIDs.remove(id)

        guard events.count != originalCount else { return false }

        persistToDisk()
        persistSyncedIDs()
        trimInMemoryOnly()
        return true
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

    /// Update the newest event matching a media assetId.
    /// Returns updated event ID if found.
    @discardableResult
    func updateLatestEventPayload(assetId: String, merge newPayload: [String: String]) -> UUID? {
        guard !assetId.isEmpty else { return nil }
        for index in events.indices.reversed() {
            if events[index].payload["assetId"] == assetId {
                for (key, value) in newPayload {
                    events[index].payload[key] = value
                }
                let id = events[index].id
                persistToDisk()
                return id
            }
        }
        return nil
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
        let migrationKey = "ryanhub_bobo_motion_episode_migration_v4"
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
        // Load events with robust per-event decoding
        if let data = try? Data(contentsOf: eventsFilePath) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Try batch decode first (fast path)
            if let decoded = try? decoder.decode([SensingEvent].self, from: data) {
                events = decoded
            } else {
                // Batch decode failed — decode individually to recover what we can
                print("[BoboDataStore] WARNING: Batch decode failed, attempting per-event recovery...")
                events = decodeEventsIndividually(from: data)
                if !events.isEmpty {
                    // Re-persist valid events so next load is clean
                    persistToDisk()
                }
            }
        }

        // Load synced IDs
        if let data = try? Data(contentsOf: syncedIDsFilePath) {
            let decoder = JSONDecoder()
            syncedEventIDs = (try? decoder.decode(Set<UUID>.self, from: data)) ?? []
        }

        // Trim memory only (disk keeps full data)
        trimInMemoryOnly()
    }

    /// Decode events one-by-one from a JSON array, skipping any that fail.
    private func decodeEventsIndividually(from data: Data) -> [SensingEvent] {
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            print("[BoboDataStore] ERROR: File is not a valid JSON array — cannot recover events")
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var recovered: [SensingEvent] = []
        var failedCount = 0

        for (index, element) in jsonArray.enumerated() {
            do {
                let elementData = try JSONSerialization.data(withJSONObject: element)
                let event = try decoder.decode(SensingEvent.self, from: elementData)
                recovered.append(event)
            } catch {
                failedCount += 1
                let modality = element["modality"] as? String ?? "unknown"
                print("[BoboDataStore] Event[\(index)] decode failed (modality=\(modality)): \(error.localizedDescription)")
            }
        }

        print("[BoboDataStore] Recovery complete: \(recovered.count) recovered, \(failedCount) failed")
        return recovered
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

    /// Number of days to keep on local device disk.
    /// Older synced events are trimmed to free phone storage.
    /// The bridge server retains all data permanently for on-demand loading.
    private static let localRetentionDays: Int = 30

    /// Remove events older than 30 days that have already been synced to the
    /// bridge server. Unsyced events are never trimmed (to prevent data loss).
    /// Runs once on init. The bridge server keeps full history — old data can
    /// be fetched on-demand when the user navigates to past dates in the UI.
    private func trimOldSyncedFromDisk() {
        let cutoff = Date().addingTimeInterval(-Double(Self.localRetentionDays) * 86400)
        let before = events.count
        events.removeAll { event in
            event.timestamp < cutoff && syncedEventIDs.contains(event.id)
        }
        let removed = before - events.count
        if removed > 0 {
            // Also clean up synced IDs for removed events
            let currentIDs = Set(events.map(\.id))
            syncedEventIDs = syncedEventIDs.intersection(currentIDs)
            persistToDisk()
            persistSyncedIDs()
            print("[BoboDataStore] Trimmed \(removed) old synced events (>30 days) from local disk")
        }
    }

    /// Trim in-memory events if exceeding cap (keep newest).
    /// Does NOT write to disk — callers must persist first if needed.
    private func trimInMemoryOnly() {
        guard events.count > Self.maxInMemoryCount else { return }
        events.sort { $0.timestamp > $1.timestamp }
        events = Array(events.prefix(Self.maxInMemoryCount))

        // Clean up synced IDs for events no longer in memory
        let currentIDs = Set(events.map(\.id))
        syncedEventIDs = syncedEventIDs.intersection(currentIDs)
    }
}
