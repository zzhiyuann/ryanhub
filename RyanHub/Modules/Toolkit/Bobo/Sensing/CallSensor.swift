import Foundation
import CallKit

// MARK: - Call Sensor

/// Observes phone call state transitions using CXCallObserver.
/// Emits a single consolidated event per call:
/// - Answered calls: one event at connect time, enriched with duration on hangup.
/// - Unanswered calls: one event when the call ends (missed/declined).
final class CallSensor: NSObject {
    private var isRunning = false
    private let callObserver = CXCallObserver()

    /// Callback invoked when a new sensing event is captured.
    var onEvent: ((SensingEvent) -> Void)?

    /// Callback to update a previously emitted event's payload (for adding duration).
    var onUpdateEvent: ((UUID, [String: String]) -> Void)?

    /// Tracks connect time per call UUID.
    private var connectTimes: [UUID: Date] = [:]

    /// Tracks whether each call is outgoing.
    private var outgoingCalls: Set<UUID> = []

    /// Tracks the emitted SensingEvent ID for connected calls, so we can enrich on hangup.
    private var emittedEventIDs: [UUID: UUID] = [:]

    /// Tracks calls we've already emitted an event for (to avoid duplicates).
    private var processedCalls: Set<UUID> = []

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
        connectTimes.removeAll()
        outgoingCalls.removeAll()
        emittedEventIDs.removeAll()
        processedCalls.removeAll()
    }
}

// MARK: - CXCallObserverDelegate

extension CallSensor: CXCallObserverDelegate {
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        guard isRunning else { return }

        let callID = call.uuid

        if call.isOutgoing && !call.hasConnected && !call.hasEnded {
            // Outgoing call initiated — just track it
            outgoingCalls.insert(callID)

        } else if call.hasConnected && !call.hasEnded {
            // Call answered — emit the single call event now
            guard !processedCalls.contains(callID) else { return }
            processedCalls.insert(callID)

            let now = Date()
            connectTimes[callID] = now

            let direction = outgoingCalls.contains(callID) ? "outgoing" : "incoming"
            let event = SensingEvent(
                modality: .call,
                payload: [
                    "direction": direction,
                    "status": "answered",
                ]
            )
            emittedEventIDs[callID] = event.id
            onEvent?(event)

        } else if call.hasEnded {
            if let connectTime = connectTimes[callID],
               let eventID = emittedEventIDs[callID] {
                // Connected call ended — enrich the existing event with duration
                let duration = Date().timeIntervalSince(connectTime)
                onUpdateEvent?(eventID, [
                    "duration": String(format: "%.0f", duration),
                ])
            } else if !processedCalls.contains(callID) {
                // Never connected — emit a single missed/unanswered event
                processedCalls.insert(callID)

                let direction = outgoingCalls.contains(callID) ? "outgoing" : "incoming"
                let status = outgoingCalls.contains(callID) ? "no_answer" : "missed"
                let event = SensingEvent(
                    modality: .call,
                    payload: [
                        "direction": direction,
                        "status": status,
                    ]
                )
                onEvent?(event)
            }

            // Clean up
            connectTimes.removeValue(forKey: callID)
            outgoingCalls.remove(callID)
            emittedEventIDs.removeValue(forKey: callID)
            processedCalls.remove(callID)
        }
    }
}
