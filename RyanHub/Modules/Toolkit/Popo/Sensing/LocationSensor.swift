import Foundation
import CoreLocation

// MARK: - Location Sensor

/// Observes significant location changes using CoreLocation.
/// Uses `startMonitoringSignificantLocationChanges()` for battery-efficient
/// monitoring (~500m threshold). Requires `.authorizedAlways` permission
/// for background location updates.
final class LocationSensor: NSObject {
    private let locationManager = CLLocationManager()
    private var isRunning = false

    /// Callback invoked when a new sensing event is captured.
    var onEvent: ((SensingEvent) -> Void)?

    // MARK: - Init

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - Lifecycle

    /// Request location authorization and start monitoring significant changes.
    func start() {
        guard !isRunning else { return }
        isRunning = true

        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            beginMonitoring()
        default:
            print("[LocationSensor] Location authorization denied")
        }
    }

    /// Stop monitoring location changes.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        locationManager.stopMonitoringSignificantLocationChanges()
    }

    // MARK: - Private

    /// Begin significant location change monitoring.
    private func beginMonitoring() {
        // Only enable background location updates if the app has the
        // "location" UIBackgroundModes capability. Setting this property
        // without the capability causes an immediate crash.
        if let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String],
           modes.contains("location") {
            locationManager.allowsBackgroundLocationUpdates = true
        }
        locationManager.startMonitoringSignificantLocationChanges()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationSensor: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if isRunning && (status == .authorizedAlways || status == .authorizedWhenInUse) {
            beginMonitoring()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let event = SensingEvent(
            modality: .location,
            payload: [
                "latitude": String(format: "%.6f", location.coordinate.latitude),
                "longitude": String(format: "%.6f", location.coordinate.longitude),
                "accuracy": String(format: "%.1f", location.horizontalAccuracy),
                "speed": String(format: "%.1f", max(0, location.speed)),
                "altitude": String(format: "%.1f", location.altitude)
            ]
        )
        onEvent?(event)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationSensor] Location error: \(error.localizedDescription)")
    }
}
