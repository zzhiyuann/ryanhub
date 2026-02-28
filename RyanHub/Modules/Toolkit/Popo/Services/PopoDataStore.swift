import Foundation

// MARK: - POPO Data Store

/// Local file-based cache for sensing events that handles persistence and sync state.
/// Stores ALL events permanently on disk (never pruned by age), keeps them
/// in memory for quick access, and clears synced events after successful POST.
final class PopoDataStore {
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
        let popoDir = documentsDir.appendingPathComponent("popo", isDirectory: true)

        // Ensure the directory exists
        try? FileManager.default.createDirectory(at: popoDir, withIntermediateDirectories: true)

        self.eventsFilePath = popoDir.appendingPathComponent("popo_events.json")
        self.syncedIDsFilePath = popoDir.appendingPathComponent("popo_synced_ids.json")

        loadFromDisk()
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
