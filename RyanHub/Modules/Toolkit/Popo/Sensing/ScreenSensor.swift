import Foundation
import UIKit

// MARK: - Screen Sensor

/// Observes device screen on/off (unlock/lock) transitions.
/// Uses protectedData notifications as a reliable proxy for screen lock state.
///
/// When the screen turns ON, emits an event with `offDuration` (how long the screen was off).
/// When the screen turns OFF, emits an event with `onDuration` (how long the screen was on).
/// The ViewModel uses the "off" event to retroactively enrich the previous "on" event.
final class ScreenSensor {
    private var isRunning = false

    /// Tracks when the screen last turned off, for computing off-duration on next unlock.
    private var lastScreenOffTime: Date?

    /// Tracks when the screen last turned on, for computing on-duration on next lock.
    private var lastScreenOnTime: Date?

    /// Callback invoked when a new sensing event is captured.
    var onEvent: ((SensingEvent) -> Void)?

    // MARK: - Lifecycle

    /// Start observing screen on/off notifications.
    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Device unlocked → screen on
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenOn),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )

        // Device locked → screen off
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenOff),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil
        )

        // Record initial state as screen on (we're running, so screen is on)
        lastScreenOnTime = Date()
        let event = SensingEvent(
            modality: .screen,
            payload: ["state": "on"]
        )
        onEvent?(event)
    }

    /// Stop observing screen notifications.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notification Handlers

    @objc private func screenOn() {
        let now = Date()

        // Calculate how long the screen was off
        var payload: [String: String] = ["state": "on"]
        if let offTime = lastScreenOffTime {
            let offDuration = now.timeIntervalSince(offTime)
            payload["offDuration"] = String(Int(offDuration))
        }

        lastScreenOnTime = now

        let event = SensingEvent(
            modality: .screen,
            payload: payload
        )
        onEvent?(event)
    }

    @objc private func screenOff() {
        let now = Date()

        // Calculate how long the screen was on
        var payload: [String: String] = ["state": "off"]
        if let onTime = lastScreenOnTime {
            let onDuration = now.timeIntervalSince(onTime)
            payload["onDuration"] = String(Int(onDuration))
        }

        lastScreenOffTime = now

        let event = SensingEvent(
            modality: .screen,
            payload: payload
        )
        onEvent?(event)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
