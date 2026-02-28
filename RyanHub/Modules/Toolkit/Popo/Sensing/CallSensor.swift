import Foundation
import CallKit

// MARK: - Call Sensor

/// Observes phone call state transitions using CXCallObserver.
/// Tracks incoming, connected, and ended calls with duration measurement.
final class CallSensor: NSObject {
    private var isRunning = false
    private let callObserver = CXCallObserver()

    /// Callback invoked when a new sensing event is captured.
    var onEvent: ((SensingEvent) -> Void)?

    /// Tracks when each active call connected (UUID -> connect time).
    private var activeCalls: [UUID: Date] = [:]

    /// Tracks which calls have been answered/connected.
    private var connectedCalls: Set<UUID> = []

    // MARK: - Lifecycle

    /// Start observing call state changes.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        callObserver.setDelegate(self, queue: nil)
    }

    /// Stop observing call state changes.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        activeCalls.removeAll()
        connectedCalls.removeAll()
    }
}

// MARK: - CXCallObserverDelegate

extension CallSensor: CXCallObserverDelegate {
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        guard isRunning else { return }

        let callID = call.uuid

        if call.hasEnded {
            // Call ended — compute duration if it was connected
            let hasConnected = connectedCalls.contains(callID)
            var payload: [String: String] = [
                "state": "ended",
                "hasConnected": hasConnected ? "true" : "false"
            ]

            if hasConnected, let connectTime = activeCalls[callID] {
                let duration = Date().timeIntervalSince(connectTime)
                payload["duration"] = String(format: "%.0f", duration)
            }

            let event = SensingEvent(modality: .call, payload: payload)
            onEvent?(event)

            // Clean up tracking state
            activeCalls.removeValue(forKey: callID)
            connectedCalls.remove(callID)

        } else if call.hasConnected {
            // Call connected (answered)
            if !connectedCalls.contains(callID) {
                connectedCalls.insert(callID)
                activeCalls[callID] = Date()

                let event = SensingEvent(
                    modality: .call,
                    payload: [
                        "state": "connected",
                        "hasConnected": "true"
                    ]
                )
                onEvent?(event)
            }

        } else if call.isOutgoing {
            // Outgoing call initiated
            activeCalls[callID] = nil

            let event = SensingEvent(
                modality: .call,
                payload: [
                    "state": "outgoing",
                    "hasConnected": "false"
                ]
            )
            onEvent?(event)

        } else {
            // Incoming call ringing
            activeCalls[callID] = nil

            let event = SensingEvent(
                modality: .call,
                payload: [
                    "state": "incoming",
                    "hasConnected": "false"
                ]
            )
            onEvent?(event)
        }
    }
}
