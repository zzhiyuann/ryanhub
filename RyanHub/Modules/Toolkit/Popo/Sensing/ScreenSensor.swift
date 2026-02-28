import Foundation
import UIKit

// MARK: - Screen Sensor

/// Observes device screen on/off (unlock/lock) transitions.
/// Uses protectedData notifications as a reliable proxy for screen lock state.
final class ScreenSensor {
    private var isRunning = false

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
        let event = SensingEvent(
            modality: .screen,
            payload: ["state": "on"]
        )
        onEvent?(event)
    }

    @objc private func screenOff() {
        let event = SensingEvent(
            modality: .screen,
            payload: ["state": "off"]
        )
        onEvent?(event)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
