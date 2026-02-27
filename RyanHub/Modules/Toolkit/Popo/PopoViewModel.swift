import Foundation

// MARK: - POPO View Model

/// Main view model for the POPO (Proactive Personal Observer) sensing module.
/// Coordinates the sensing engine and exposes observable state for the UI.
@MainActor
@Observable
final class PopoViewModel {
    // MARK: - State

    /// The sensing engine that manages all sensors.
    let engine = SensingEngine()

    /// Whether sensing has been toggled on by the user.
    var sensingEnabled: Bool = false {
        didSet {
            if sensingEnabled {
                engine.startSensing()
            } else {
                engine.stopSensing()
            }
            // Persist the preference
            UserDefaults.standard.set(sensingEnabled, forKey: StorageKeys.sensingEnabled)
        }
    }

    /// The currently selected modality filter for the event list (nil = all).
    var selectedModality: SensingModality?

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

    // MARK: - Init

    init() {
        // Restore persisted preference
        let wasEnabled = UserDefaults.standard.bool(forKey: StorageKeys.sensingEnabled)
        if wasEnabled {
            sensingEnabled = true
            engine.startSensing()
        }
    }

    // MARK: - Actions

    /// Force an immediate sync of pending events.
    func syncNow() async {
        await engine.syncPendingEvents()
    }

    // MARK: - Storage Keys

    private enum StorageKeys {
        static let sensingEnabled = "ryanhub_popo_sensing_enabled"
    }
}
