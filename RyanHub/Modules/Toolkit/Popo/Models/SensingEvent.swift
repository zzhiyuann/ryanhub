import Foundation

// MARK: - Sensing Modality

/// The type of behavioral signal being observed.
enum SensingModality: String, Codable, CaseIterable {
    case motion          // Walking, running, driving, stationary
    case steps           // Step count
    case heartRate       // BPM
    case hrv             // Heart rate variability (ms)
    case sleep           // Sleep analysis
    case location        // Significant location change
    case screen          // Screen on/off, app foreground/background
    case workout         // HealthKit workout
    case activeEnergy    // Active energy burned (kcal)
    case basalEnergy     // Basal (resting) energy burned (kcal)
    case respiratoryRate // Breaths per minute
    case bloodOxygen     // SpO2 percentage
    case noiseExposure   // Environmental audio exposure (dB)
    case battery         // Battery level & charging state
    case call            // Phone call state (incoming, connected, ended)
    case wifi            // Wi-Fi network info
    case bluetooth       // Bluetooth device connections
    case visit           // CLVisit-based place visits
}

// MARK: - Sensing Event

/// A single behavioral sensing data point captured by any sensor modality.
/// Uses [String: String] for the payload to maintain Codable compliance while
/// remaining flexible enough to represent diverse data types.
///
/// Payload examples by modality:
/// - motion:          {"activityType": "walking", "confidence": "high"}
/// - steps:           {"steps": "1234", "source": "healthkit"}
/// - heartRate:       {"bpm": "72", "source": "watch"}
/// - hrv:             {"sdnn": "42.5", "source": "watch"}
/// - sleep:           {"stage": "asleep", "startDate": "...", "endDate": "..."}
/// - location:        {"latitude": "38.0336", "longitude": "-78.5080", "accuracy": "10.0"}
/// - screen:          {"state": "foreground", "sessionDuration": "300"}
/// - workout:         {"type": "running", "duration": "1800", "calories": "250"}
/// - activeEnergy:    {"kcal": "45.2", "source": "watch"}
/// - basalEnergy:     {"kcal": "62.0", "source": "watch"}
/// - respiratoryRate: {"breathsPerMin": "15.5", "source": "watch"}
/// - bloodOxygen:     {"spo2": "98.0", "source": "watch"}
/// - noiseExposure:   {"decibels": "72.3", "source": "watch"}
struct SensingEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let modality: SensingModality
    let payload: [String: String]

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        modality: SensingModality,
        payload: [String: String]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.modality = modality
        self.payload = payload
    }
}
