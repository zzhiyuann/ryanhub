import Foundation
import CoreMotion

// MARK: - Motion Sensor

/// Observes user motion activity and step counts using CoreMotion.
/// Activity updates (walking, running, driving, stationary, cycling) arrive
/// automatically when the state changes. Step count updates are delivered
/// via CMPedometer live updates.
final class MotionSensor {
    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private var isRunning = false

    /// Callback invoked when a new sensing event is captured.
    var onEvent: ((SensingEvent) -> Void)?

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
    /// CoreMotion delivers updates on state transitions automatically.
    private func startActivityUpdates() {
        let queue = OperationQueue()
        queue.name = "com.ryanhub.popo.motion"
        queue.maxConcurrentOperationCount = 1

        activityManager.startActivityUpdates(to: queue) { [weak self] activity in
            guard let activity else { return }
            let activityType = Self.activityTypeString(from: activity)
            let confidence = Self.confidenceString(from: activity.confidence)

            let event = SensingEvent(
                modality: .motion,
                payload: [
                    "activityType": activityType,
                    "confidence": confidence
                ]
            )
            self?.onEvent?(event)
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
    private static func confidenceString(from confidence: CMMotionActivityConfidence) -> String {
        switch confidence {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        @unknown default: return "unknown"
        }
    }
}
