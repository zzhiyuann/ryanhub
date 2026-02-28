import Foundation
import UIKit

// MARK: - Screen Sensor

/// Observes app foreground/background transitions to track screen usage patterns.
/// Listens to UIApplication lifecycle notifications and calculates session durations.
///
/// Note: We cannot access other apps' usage without the DeviceActivity framework
/// (which requires special entitlements). For now, we track our own app's usage
/// and infer phone usage from lock/unlock patterns.
final class ScreenSensor {
    private var isRunning = false
    private var lastForegroundTime: Date?

    /// Callback invoked when a new sensing event is captured.
    var onEvent: ((SensingEvent) -> Void)?

    // MARK: - Lifecycle

    /// Start observing app lifecycle notifications.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastForegroundTime = Date()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        // Record initial foreground event
        let event = SensingEvent(
            modality: .screen,
            payload: [
                "state": "foreground",
                "event": "app_opened"
            ]
        )
        onEvent?(event)
    }

    /// Stop observing app lifecycle notifications.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        lastForegroundTime = nil
    }

    // MARK: - Notification Handlers

    @objc private func appDidBecomeActive() {
        lastForegroundTime = Date()

        let event = SensingEvent(
            modality: .screen,
            payload: [
                "state": "foreground",
                "event": "app_opened"
            ]
        )
        onEvent?(event)
    }

    @objc private func appWillResignActive() {
        let sessionDuration: TimeInterval
        if let foregroundTime = lastForegroundTime {
            sessionDuration = Date().timeIntervalSince(foregroundTime)
        } else {
            sessionDuration = 0
        }

        let event = SensingEvent(
            modality: .screen,
            payload: [
                "state": "background",
                "event": "app_closed",
                "sessionDuration": String(format: "%.0f", sessionDuration)
            ]
        )
        onEvent?(event)
        lastForegroundTime = nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
