import Foundation
import CoreMotion

// MARK: - Motion Sensor

/// Observes user motion activity and step counts using CoreMotion.
/// Emits episode-based activity events: each event represents the START of an activity.
/// When the activity changes, SensingEngine enriches the previous episode with
/// duration and nextActivity. Unknown and low-confidence readings are ignored.
final class MotionSensor {
    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private var isRunning = false

    /// Callback invoked when a new sensing event is captured.
    var onEvent: ((SensingEvent) -> Void)?

    // MARK: - Episode Tracking

    /// The current activity type being tracked.
    private var currentActivity: String?

    /// Minimum time (seconds) between activity transitions to avoid noisy flapping.
    private static let transitionCooldown: TimeInterval = 10

    /// Timestamp when the current activity episode started.
    private var currentActivityStartTime: Date?

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
    /// Each emitted event marks the START of an activity episode. SensingEngine
    /// enriches the previous episode with duration and nextActivity upon receiving
    /// the new event. Unknown and low-confidence readings are silently ignored.
    private func startActivityUpdates() {
        let queue = OperationQueue()
        queue.name = "com.ryanhub.bobo.motion"
        queue.maxConcurrentOperationCount = 1

        activityManager.startActivityUpdates(to: queue) { [weak self] activity in
            guard let self, let activity else { return }

            let activityType = Self.activityTypeString(from: activity)

            // Ignore unknown — transient classifier noise
            guard activityType != "unknown" else { return }

            // Ignore low confidence — too noisy
            guard activity.confidence != .low else { return }

            // Only emit when activity type actually changes
            guard activityType != self.currentActivity else { return }

            // Enforce cooldown to prevent rapid flapping
            let now = Date()
            if let start = self.currentActivityStartTime,
               now.timeIntervalSince(start) < Self.transitionCooldown {
                return
            }

            // Update tracking state
            self.currentActivity = activityType
            self.currentActivityStartTime = now

            // Emit episode start — SensingEngine will enrich the previous episode
            let event = SensingEvent(
                modality: .motion,
                payload: [
                    "activityType": activityType,
                    "confidence": Self.confidenceString(from: activity.confidence),
                ]
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
