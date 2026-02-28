import Foundation
import CoreMotion

// MARK: - Motion Sensor

/// Observes user motion activity and step counts using CoreMotion.
/// Activity updates (walking, running, driving, stationary, cycling) arrive
/// automatically when the state changes. Implements HAR (Human Activity Recognition)
/// temporal clustering to reduce noise — only emits transition events when activity
/// type changes with sufficient confidence and cooldown.
final class MotionSensor {
    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private var isRunning = false

    /// Callback invoked when a new sensing event is captured.
    var onEvent: ((SensingEvent) -> Void)?

    // MARK: - HAR Temporal Clustering State

    /// The last activity type that was actually reported (emitted as an event).
    private var lastReportedActivity: String?

    /// Timestamp when the last activity transition was reported.
    private var lastActivityChangeTime: Date?

    /// Minimum time (seconds) between activity transitions to avoid noisy flapping.
    private static let transitionCooldown: TimeInterval = 10

    // MARK: - Lifecycle

    /// Start observing motion activity and step count updates.
    func start() {
        guard !isRunning else { return }
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("[MotionSensor] Activity monitoring not available on this device")
            return
        }
        isRunning = true
        startActivityUpdates()
        startPedometerUpdates()
    }

    /// Stop all motion observations.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()
    }

    // MARK: - Activity Updates

    /// Monitor real-time activity type changes (walking, running, driving, etc).
    /// Applies HAR temporal clustering: only emits a transition event when the
    /// activity type changes, confidence is at least medium, and the transition
    /// cooldown has elapsed.
    private func startActivityUpdates() {
        let queue = OperationQueue()
        queue.name = "com.ryanhub.bobo.motion"
        queue.maxConcurrentOperationCount = 1

        activityManager.startActivityUpdates(to: queue) { [weak self] activity in
            guard let self, let activity else { return }

            let activityType = Self.activityTypeString(from: activity)

            // Ignore "unknown" — these are transient classifier uncertainty (picking up phone, shifting position)
            // Not a real activity transition; do not update lastReportedActivity or lastActivityChangeTime
            guard activityType != "unknown" else { return }

            let confidence = activity.confidence

            // Filter 1: Ignore low-confidence readings — too noisy
            guard confidence != .low else { return }

            // Filter 2: Only emit when activity type actually changes
            guard activityType != self.lastReportedActivity else { return }

            // Filter 3: Enforce transition cooldown to prevent rapid flapping
            let now = Date()
            if let lastChange = self.lastActivityChangeTime,
               now.timeIntervalSince(lastChange) < Self.transitionCooldown {
                return
            }

            // Build transition payload with episode context
            var payload: [String: String] = [
                "activityType": activityType,
                "confidence": Self.confidenceString(from: confidence)
            ]

            // Include previous activity context for transition awareness
            if let previousActivity = self.lastReportedActivity {
                payload["previousActivity"] = previousActivity
                payload["transitionType"] = "\(previousActivity)_to_\(activityType)"

                // Calculate how long the previous activity lasted
                if let lastChange = self.lastActivityChangeTime {
                    let previousDuration = now.timeIntervalSince(lastChange)
                    payload["previousDuration"] = String(format: "%.0f", previousDuration)
                }
            }

            // Update tracking state
            self.lastReportedActivity = activityType
            self.lastActivityChangeTime = now

            let event = SensingEvent(
                modality: .motion,
                payload: payload
            )
            self.onEvent?(event)
        }
    }

    // MARK: - Pedometer Updates

    /// Monitor live step count updates from the pedometer.
    /// Updates arrive periodically (roughly every few seconds when active).
    private func startPedometerUpdates() {
        guard CMPedometer.isStepCountingAvailable() else {
            print("[MotionSensor] Step counting not available")
            return
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            guard let data else {
                if let error {
                    print("[MotionSensor] Pedometer error: \(error.localizedDescription)")
                }
                return
            }

            let event = SensingEvent(
                modality: .steps,
                payload: [
                    "steps": "\(data.numberOfSteps)",
                    "source": "coremotion",
                    "distance": data.distance.map { "\($0)" } ?? "unknown"
                ]
            )
            self?.onEvent?(event)
        }
    }

    // MARK: - Helpers

    /// Convert a CMMotionActivity to a human-readable activity type string.
    private static func activityTypeString(from activity: CMMotionActivity) -> String {
        if activity.walking { return "walking" }
        if activity.running { return "running" }
        if activity.cycling { return "cycling" }
        if activity.automotive { return "automotive" }
        if activity.stationary { return "stationary" }
        return "unknown"
    }

    /// Convert a CMMotionActivityConfidence to a human-readable string.
    static func confidenceString(from confidence: CMMotionActivityConfidence) -> String {
        switch confidence {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        @unknown default: return "unknown"
        }
    }
}
