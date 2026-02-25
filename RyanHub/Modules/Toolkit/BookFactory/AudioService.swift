import Foundation
import AVFoundation
import os

private let logger = Logger(subsystem: "com.ryanhub.app", category: "AudioService")

/// Manages audio session configuration and provides utility functions
/// for the Book Factory audio playback system.
///
/// The actual playback logic lives in `AudioPlayerViewModel` using AVPlayer.
/// This service handles session lifecycle and provides helpers for
/// background audio, interruption handling, and route changes.
enum AudioService {

    // MARK: - Session Configuration

    /// Configure the shared audio session for spoken audio playback.
    /// Call once at app launch or when entering Book Factory.
    static func configureSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
            logger.info("Audio session configured for spoken audio playback")
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Deactivate the audio session when audio is no longer needed.
    static func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            logger.info("Audio session deactivated")
        } catch {
            logger.error("Failed to deactivate audio session: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Interruption Handling

    /// Observes audio session interruptions (e.g. phone calls) and provides
    /// callbacks for the player to pause/resume.
    static func observeInterruptions(
        onBegan: @escaping () -> Void,
        onEnded: @escaping (_ shouldResume: Bool) -> Void
    ) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { notification in
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }

            switch type {
            case .began:
                logger.info("Audio interruption began")
                onBegan()
            case .ended:
                let optionsValue = (info[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                let shouldResume = options.contains(.shouldResume)
                logger.info("Audio interruption ended, shouldResume: \(shouldResume)")
                onEnded(shouldResume)
            @unknown default:
                break
            }
        }
    }

    // MARK: - Route Change Handling

    /// Observes audio route changes (e.g. headphones disconnected).
    /// Returns an observer token that should be removed when no longer needed.
    static func observeRouteChanges(
        onOldDeviceUnavailable: @escaping () -> Void
    ) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { notification in
            guard let info = notification.userInfo,
                  let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                return
            }

            if reason == .oldDeviceUnavailable {
                logger.info("Audio route changed: old device unavailable (headphones removed?)")
                onOldDeviceUnavailable()
            }
        }
    }

    // MARK: - Utility

    /// Formats seconds into a display duration string (e.g. "1:23:45" or "5:30").
    static func formatDuration(_ seconds: Double) -> String {
        BookFormatting.duration(seconds)
    }

    /// Returns the current audio output route description.
    static var currentRoute: String {
        let route = AVAudioSession.sharedInstance().currentRoute
        let outputs = route.outputs.map(\.portName).joined(separator: ", ")
        return outputs.isEmpty ? "No output" : outputs
    }
}
