import Foundation
import WatchConnectivity

// MARK: - Watch Session Manager

/// iPhone-side WCSession singleton that manages communication with the paired Apple Watch.
///
/// Responsibilities:
/// - Sends start/stop audio commands to the Watch.
/// - Receives raw PCM audio data from the Watch and forwards it via `onAudioData`.
/// - Publishes reachability and streaming state for UI consumption.
@MainActor
@Observable
final class WatchSessionManager: NSObject {
    // MARK: - Singleton

    static let shared = WatchSessionManager()

    // MARK: - Observable State

    /// Whether the paired Watch is currently reachable.
    private(set) var isWatchReachable = false

    /// Whether the Watch is actively streaming audio data.
    /// Internal setter so SensingEngine can reset on fallback.
    var isWatchStreaming = false

    // MARK: - Audio Data Callback

    /// Called on the main thread when PCM audio data arrives from the Watch.
    var onAudioData: ((Data) -> Void)?

    // MARK: - WCSession

    private var wcSession: WCSession?

    // MARK: - Init

    private override init() {
        super.init()
        setupSession()
    }

    // MARK: - Session Setup

    private func setupSession() {
        guard WCSession.isSupported() else {
            print("[WatchSessionManager] WCSession not supported on this device")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        wcSession = session
    }

    // MARK: - Commands

    /// Send a command to the Watch to start audio capture.
    /// Does not pre-check isReachable — attempts to send regardless.
    /// The error handler silently absorbs failures (Watch will respond when reachable).
    func startWatchAudio() {
        guard let session = wcSession else {
            print("[WatchSessionManager] Cannot start Watch audio — no WCSession")
            return
        }

        session.sendMessage(["command": "start_audio"], replyHandler: nil) { error in
            print("[WatchSessionManager] start_audio send failed (will retry when reachable): \(error.localizedDescription)")
        }
        isWatchStreaming = true
        print("[WatchSessionManager] Sent start_audio command to Watch")
    }

    /// Send a command to the Watch to stop audio capture.
    func stopWatchAudio() {
        guard let session = wcSession else { return }

        // Try to send stop even if not reachable — it will be delivered when reachable
        session.sendMessage(["command": "stop_audio"], replyHandler: nil) { error in
            print("[WatchSessionManager] Failed to send stop_audio: \(error.localizedDescription)")
        }
        isWatchStreaming = false
        print("[WatchSessionManager] Sent stop_audio command to Watch")
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("[WatchSessionManager] Activation failed: \(error.localizedDescription)")
        } else {
            print("[WatchSessionManager] Activated: \(activationState.rawValue)")
        }
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("[WatchSessionManager] Session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("[WatchSessionManager] Session deactivated — reactivating")
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        print("[WatchSessionManager] Watch reachability changed: \(reachable)")
        Task { @MainActor in
            let wasReachable = self.isWatchReachable
            self.isWatchReachable = reachable

            if reachable && !wasReachable {
                // Watch just became reachable
                NotificationCenter.default.post(name: .watchDidBecomeReachable, object: nil)
                print("[WatchSessionManager] Watch became reachable — posted notification")
            } else if !reachable && self.isWatchStreaming {
                // Watch disconnected during active stream
                self.isWatchStreaming = false
                NotificationCenter.default.post(name: .watchAudioStreamDidStop, object: nil)
                print("[WatchSessionManager] Watch disconnected during stream — posted stop notification")
            }
        }
    }

    /// Receive raw PCM audio data from the Watch.
    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        Task { @MainActor in
            self.onAudioData?(messageData)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when Watch audio streaming stops unexpectedly (e.g., Watch disconnects).
    static let watchAudioStreamDidStop = Notification.Name("watchAudioStreamDidStop")

    /// Posted when the Watch becomes reachable (was unreachable, now reachable).
    static let watchDidBecomeReachable = Notification.Name("watchDidBecomeReachable")
}
