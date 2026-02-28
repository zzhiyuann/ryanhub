import Foundation
import CoreLocation

// MARK: - Location Sensor

/// Observes significant location changes and visits using CoreLocation.
/// Uses `startMonitoringSignificantLocationChanges()` for battery-efficient
/// monitoring (~500m threshold) and `startMonitoringVisits()` for detecting
/// arrivals/departures at meaningful places.
/// Requires `.authorizedAlways` permission for background location updates.
final class LocationSensor: NSObject {
    private let locationManager = CLLocationManager()
    private var isRunning = false

    /// Callback invoked when a new sensing event is captured.
    var onEvent: ((SensingEvent) -> Void)?

    /// Base URL for the bridge server, derived from the shared server URL setting.
    /// Falls back to the default food analysis URL (same host, port 18790).
    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? AppState.defaultFoodAnalysisURL
    }

    // MARK: - Init

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - Lifecycle

    /// Request location authorization and start monitoring significant changes + visits.
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

    /// Stop monitoring location changes and visits.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopMonitoringVisits()
    }

    // MARK: - Private

    /// Begin significant location change monitoring and visit monitoring.
    private func beginMonitoring() {
        // Only enable background location updates if the app has the
        // "location" UIBackgroundModes capability. Setting this property
        // without the capability causes an immediate crash.
        if let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String],
           modes.contains("location") {
            locationManager.allowsBackgroundLocationUpdates = true
        }
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startMonitoringVisits()
    }

    // MARK: - Semantic Enrichment

    /// POST to the bridge server for semantic location enrichment, then emit an
    /// enriched SensingEvent with the semantic label and address data.
    private func enrichLocation(latitude: Double, longitude: Double, timestamp: Date) {
        Task {
            let endpoint = "\(Self.bridgeBaseURL)/bobo/location/enrich"
            guard let url = URL(string: endpoint) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 10

            let body: [String: Any] = [
                "latitude": latitude,
                "longitude": longitude,
                "timestamp": ISO8601DateFormatter().string(from: timestamp)
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let enrichment = result["enrichment"] as? [String: Any] {
                    let label = enrichment["semantic_label"] as? String ?? ""
                    let address = enrichment["address"] as? String ?? ""
                    let placeName = enrichment["place_name"] as? String ?? ""
                    let nearbyPois = (enrichment["nearby_pois"] as? [String])?.joined(separator: ", ") ?? ""
                    let displayName = !placeName.isEmpty ? placeName : (!label.isEmpty ? label : address)
                    print("[LocationSensor] Enriched: \(displayName)")

                    // Emit a new enriched event with Google Maps data
                    let enrichedEvent = SensingEvent(
                        modality: .location,
                        payload: [
                            "latitude": String(format: "%.6f", latitude),
                            "longitude": String(format: "%.6f", longitude),
                            "semanticLabel": label,
                            "placeName": placeName,
                            "address": address,
                            "neighborhood": enrichment["neighborhood"] as? String ?? "",
                            "city": enrichment["city"] as? String ?? "",
                            "placeType": enrichment["place_type"] as? String ?? "",
                            "nearbyPOIs": nearbyPois,
                            "enriched": "true"
                        ]
                    )
                    self.onEvent?(enrichedEvent)
                }
            } catch {
                // Best-effort enrichment — log but do not propagate errors.
                // The raw location event was already emitted; the timeline will
                // simply show coordinates instead of a semantic label.
                print("[LocationSensor] Enrichment request failed: \(error.localizedDescription)")
            }
        }
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
                "horizontalAccuracy": String(format: "%.1f", location.horizontalAccuracy),
                "altitude": String(format: "%.1f", location.altitude),
                "speed": String(format: "%.1f", max(0, location.speed))
            ]
        )
        onEvent?(event)

        // Fire-and-forget enrichment call to bridge server
        enrichLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp
        )
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        // CLVisit with distantFuture departure means the user has arrived but not left yet
        let arrivalStr = ISO8601DateFormatter().string(from: visit.arrivalDate)
        let departureStr: String
        if visit.departureDate == .distantFuture {
            departureStr = "ongoing"
        } else {
            departureStr = ISO8601DateFormatter().string(from: visit.departureDate)
        }

        let event = SensingEvent(
            modality: .location,
            payload: [
                "latitude": String(format: "%.6f", visit.coordinate.latitude),
                "longitude": String(format: "%.6f", visit.coordinate.longitude),
                "horizontalAccuracy": String(format: "%.1f", visit.horizontalAccuracy),
                "visit": "true",
                "arrivalDate": arrivalStr,
                "departureDate": departureStr
            ]
        )
        onEvent?(event)

        // Enrich the visit location as well
        enrichLocation(
            latitude: visit.coordinate.latitude,
            longitude: visit.coordinate.longitude,
            timestamp: visit.arrivalDate
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationSensor] Location error: \(error.localizedDescription)")
    }
}
