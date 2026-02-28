import Foundation
import UIKit

// MARK: - Battery Sensor

/// Monitors device battery level and charging state.
/// Battery level can hint at indoor/charging behavior.
final class BatterySensor {
    private var isRunning = false
    private var timer: Timer?
    private var lastReportedLevel: Float = -1
    private var lastReportedState: UIDevice.BatteryState = .unknown

    /// Callback invoked when a new sensing event is captured.
    var onEvent: ((SensingEvent) -> Void)?

    // MARK: - Lifecycle

    /// Start monitoring battery level and charging state.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        UIDevice.current.isBatteryMonitoringEnabled = true

        // Report initial state
        reportBatteryState()

        // Check every 10 minutes for changes
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.reportBatteryState()
        }
    }

    /// Stop monitoring battery state.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        timer?.invalidate()
        timer = nil
        UIDevice.current.isBatteryMonitoringEnabled = false
    }

    // MARK: - Background One-Shot

    /// Immediately read and report battery state, bypassing the change threshold.
    /// Suitable for background wake-ups where we want a snapshot regardless.
    func checkNow() {
        UIDevice.current.isBatteryMonitoringEnabled = true

        let level = UIDevice.current.batteryLevel
        let state = UIDevice.current.batteryState

        let stateString: String
        switch state {
        case .charging: stateString = "charging"
        case .full: stateString = "full"
        case .unplugged: stateString = "unplugged"
        default: stateString = "unknown"
        }

        let event = SensingEvent(
            modality: .battery,
            payload: [
                "level": String(format: "%.0f", level * 100),
                "state": stateString,
                "source": "background_check"
            ]
        )
        onEvent?(event)

        // Update tracked state so periodic checks don't re-report the same value
        lastReportedLevel = level
        lastReportedState = state
    }

    // MARK: - Internal

    private func reportBatteryState() {
        let level = UIDevice.current.batteryLevel
        let state = UIDevice.current.batteryState

        // Only report if level changed by >5% or state changed
        let levelChanged = abs(level - lastReportedLevel) > 0.05
        let stateChanged = state != lastReportedState

        guard levelChanged || stateChanged else { return }

        lastReportedLevel = level
        lastReportedState = state

        let stateString: String
        switch state {
        case .charging: stateString = "charging"
        case .full: stateString = "full"
        case .unplugged: stateString = "unplugged"
        default: stateString = "unknown"
        }

        let event = SensingEvent(
            modality: .battery,
            payload: [
                "level": String(format: "%.0f", level * 100),
                "state": stateString
            ]
        )
        onEvent?(event)
    }
}
