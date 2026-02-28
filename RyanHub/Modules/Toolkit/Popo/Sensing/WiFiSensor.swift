import Foundation
import SystemConfiguration.CaptiveNetwork

// MARK: - WiFi Sensor

/// Detects current WiFi network SSID.
/// Useful for identifying "home" vs "office" by known networks.
///
/// Note: Reading SSID requires location permission + the
/// `com.apple.developer.networking.wifi-info` entitlement.
/// Without the entitlement, `getCurrentSSID()` will gracefully return nil.
final class WiFiSensor {
    private var isRunning = false
    private var timer: Timer?
    private var lastSSID: String?

    /// Callback invoked when a new sensing event is captured.
    var onEvent: ((SensingEvent) -> Void)?

    // MARK: - Lifecycle

    /// Start monitoring WiFi SSID changes.
    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Check immediately
        checkWiFi()

        // Re-check every 2 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.checkWiFi()
        }
    }

    /// Stop monitoring WiFi.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Background One-Shot

    /// Immediately read and report the current SSID, bypassing the change check.
    /// Suitable for background wake-ups where we want a snapshot regardless.
    func checkNow() {
        let ssid = getCurrentSSID()

        let event = SensingEvent(
            modality: .wifi,
            payload: [
                "ssid": ssid ?? "disconnected",
                "connected": ssid != nil ? "true" : "false",
                "source": "background_check"
            ]
        )
        onEvent?(event)

        // Update tracked state so periodic checks don't re-report the same value
        lastSSID = ssid
    }

    // MARK: - Internal

    private func checkWiFi() {
        let ssid = getCurrentSSID()

        // Only report if SSID changed
        guard ssid != lastSSID else { return }
        lastSSID = ssid

        let event = SensingEvent(
            modality: .wifi,
            payload: [
                "ssid": ssid ?? "disconnected",
                "connected": ssid != nil ? "true" : "false"
            ]
        )
        onEvent?(event)
    }

    /// Retrieve the current WiFi SSID using CaptiveNetwork API.
    /// Returns nil if not connected to WiFi or if the WiFi entitlement is missing.
    private func getCurrentSSID() -> String? {
        // CNCopyCurrentNetworkInfo is deprecated in iOS 14+ but still functional.
        // The modern replacement (NEHotspotNetwork.fetchCurrent) is async and
        // requires the same entitlement, so we use this for simplicity.
        if let interfaces = CNCopySupportedInterfaces() as? [String] {
            for interface in interfaces {
                if let info = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any],
                   let networkSSID = info[kCNNetworkInfoKeySSID as String] as? String {
                    return networkSSID
                }
            }
        }
        return nil
    }
}
