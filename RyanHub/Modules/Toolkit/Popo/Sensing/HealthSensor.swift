import Foundation
import HealthKit

// MARK: - Health Sensor

/// Observes health data from HealthKit including heart rate, HRV, sleep,
/// and workout completions. Apple Watch data flows through HealthKit
/// automatically, so no special Watch code is needed.
///
/// Uses HKObserverQuery for background notifications on new data,
/// and HKSampleQuery for batch fetching recent samples.
///
/// Heart rate data receives smart throttling: readings are buffered and
/// emitted as 1-minute aggregates (avg/min/max/count) to prevent timeline
/// spam from continuous Apple Watch monitoring (~12 readings/min).
/// Anomalies (tachycardia, bradycardia, sudden spikes) bypass the throttle
/// and emit immediately.
final class HealthSensor {
    private let healthStore: HKHealthStore?
    private var observerQueries: [HKObserverQuery] = []
    private var isRunning = false

    // MARK: - Heart Rate Throttling State

    /// Buffer of BPM readings awaiting aggregation.
    private var hrBuffer: [Double] = []

    /// Timestamp of the last aggregated HR emit.
    private var lastHREmitTime: Date?

    /// Rolling average from the previous aggregation window, used for spike detection.
    private var previousMinuteAvgBPM: Double?

    /// Minimum interval (seconds) between aggregated HR emits.
    private static let hrEmitInterval: TimeInterval = 60

    // MARK: - Active Energy Throttling State

    /// Buffer of kcal readings awaiting hourly aggregation.
    private var activeEnergyBuffer: [Double] = []

    /// Timestamp of the last aggregated active energy emit.
    private var lastActiveEnergyEmitTime: Date?

    /// Minimum interval (seconds) between aggregated active energy emits (1 hour).
    private static let activeEnergyEmitInterval: TimeInterval = 3600

    // MARK: - Anomaly Thresholds

    /// Resting heart rate above this is considered tachycardia.
    private static let tachycardiaThreshold: Double = 100

    /// Heart rate below this is considered bradycardia.
    private static let bradycardiaThreshold: Double = 45

    /// A jump larger than this from the previous minute's average triggers an anomaly.
    private static let spikeThreshold: Double = 30

    /// The HealthKit data types POPO requests read access for.
    private static let readTypes: Set<HKSampleType> = {
        var types = Set<HKSampleType>()
        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let basalEnergy = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            types.insert(basalEnergy)
        }
        if let respiratoryRate = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(respiratoryRate)
        }
        if let bloodOxygen = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            types.insert(bloodOxygen)
        }
        if let noiseExposure = HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure) {
            types.insert(noiseExposure)
        }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        types.insert(HKWorkoutType.workoutType())
        return types
    }()

    /// Callback invoked when a new sensing event is captured.
    var onEvent: ((SensingEvent) -> Void)?

    // MARK: - Init

    init() {
        self.healthStore = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }

    // MARK: - Lifecycle

    /// Request HealthKit authorization and start observer queries.
    func start() {
        guard !isRunning else { return }
        guard let healthStore else {
            print("[HealthSensor] HealthKit not available on this device")
            return
        }
        isRunning = true

        healthStore.requestAuthorization(toShare: nil, read: Self.readTypes as Set<HKObjectType>) { [weak self] success, error in
            if success {
                self?.startObservers()
                self?.fetchRecentSamples()
            } else {
                print("[HealthSensor] Authorization failed: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }

    /// Stop all observer queries and clear HR throttling state.
    func stop() {
        guard isRunning, let healthStore else { return }
        isRunning = false
        for query in observerQueries {
            healthStore.stop(query)
        }
        observerQueries.removeAll()

        // Reset HR throttling state
        hrBuffer.removeAll()
        lastHREmitTime = nil
        previousMinuteAvgBPM = nil
    }

    // MARK: - Observer Queries

    /// Set up HKObserverQuery for each data type to be notified of new samples.
    private func startObservers() {
        guard let healthStore else { return }

        // Heart rate observer
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
                if error == nil {
                    self?.fetchHeartRate()
                }
                completionHandler()
            }
            healthStore.execute(query)
            observerQueries.append(query)
        }

        // HRV observer
        if let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            let query = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] _, completionHandler, error in
                if error == nil {
                    self?.fetchHRV()
                }
                completionHandler()
            }
            healthStore.execute(query)
            observerQueries.append(query)
        }

        // Sleep observer
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completionHandler, error in
                if error == nil {
                    self?.fetchSleep()
                }
                completionHandler()
            }
            healthStore.execute(query)
            observerQueries.append(query)
        }

        // Workout observer
        let workoutQuery = HKObserverQuery(sampleType: HKWorkoutType.workoutType(), predicate: nil) { [weak self] _, completionHandler, error in
            if error == nil {
                self?.fetchWorkouts()
            }
            completionHandler()
        }
        healthStore.execute(workoutQuery)
        observerQueries.append(workoutQuery)

        // Active energy observer
        if let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let query = HKObserverQuery(sampleType: activeEnergyType, predicate: nil) { [weak self] _, completionHandler, error in
                if error == nil {
                    self?.fetchActiveEnergy()
                }
                completionHandler()
            }
            healthStore.execute(query)
            observerQueries.append(query)
        }

        // Basal energy observer
        if let basalEnergyType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            let query = HKObserverQuery(sampleType: basalEnergyType, predicate: nil) { [weak self] _, completionHandler, error in
                if error == nil {
                    self?.fetchBasalEnergy()
                }
                completionHandler()
            }
            healthStore.execute(query)
            observerQueries.append(query)
        }

        // Respiratory rate observer
        if let respiratoryRateType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
            let query = HKObserverQuery(sampleType: respiratoryRateType, predicate: nil) { [weak self] _, completionHandler, error in
                if error == nil {
                    self?.fetchRespiratoryRate()
                }
                completionHandler()
            }
            healthStore.execute(query)
            observerQueries.append(query)
        }

        // Blood oxygen (SpO2) observer
        if let bloodOxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            let query = HKObserverQuery(sampleType: bloodOxygenType, predicate: nil) { [weak self] _, completionHandler, error in
                if error == nil {
                    self?.fetchBloodOxygen()
                }
                completionHandler()
            }
            healthStore.execute(query)
            observerQueries.append(query)
        }

        // Noise exposure observer
        if let noiseExposureType = HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure) {
            let query = HKObserverQuery(sampleType: noiseExposureType, predicate: nil) { [weak self] _, completionHandler, error in
                if error == nil {
                    self?.fetchNoiseExposure()
                }
                completionHandler()
            }
            healthStore.execute(query)
            observerQueries.append(query)
        }
    }

    // MARK: - Fetch Methods

    /// Fetch recent samples on startup for all monitored types.
    private func fetchRecentSamples() {
        fetchHeartRate()
        fetchHRV()
        fetchSleep()
        fetchWorkouts()
        fetchActiveEnergy()
        fetchBasalEnergy()
        fetchRespiratoryRate()
        fetchBloodOxygen()
        fetchNoiseExposure()
    }

    /// Fetch recent heart rate samples and apply smart throttling.
    ///
    /// Instead of emitting every individual reading (which can be ~12/min with
    /// continuous Apple Watch HR monitoring), readings are buffered and emitted
    /// as a single aggregated event once per minute with avg/min/max/count.
    ///
    /// Anomalies bypass the throttle and emit immediately:
    /// - Resting HR > 100 bpm (tachycardia)
    /// - HR < 45 bpm (bradycardia)
    /// - Sudden change > 30 bpm from previous minute's average
    private func fetchHeartRate() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let predicate = HKQuery.predicateForSamples(withStart: fiveMinutesAgo, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 30,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self, let samples = samples as? [HKQuantitySample], error == nil else { return }
            let source = samples.first?.sourceRevision.source.name ?? "watch"

            for sample in samples {
                let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))

                // Check for anomaly — emit immediately if detected
                if self.isHeartRateAnomaly(bpm) {
                    let event = SensingEvent(
                        timestamp: sample.startDate,
                        modality: .heartRate,
                        payload: [
                            "bpm": String(format: "%.0f", bpm),
                            "anomaly": "true",
                            "reason": self.anomalyReason(bpm),
                            "source": source
                        ]
                    )
                    self.onEvent?(event)
                } else {
                    // Normal reading — add to buffer
                    self.hrBuffer.append(bpm)
                }
            }

            // Emit aggregated event if enough time has elapsed
            self.emitAggregatedHeartRateIfReady(source: source)
        }
        healthStore?.execute(query)
    }

    /// Check if a heart rate value qualifies as an anomaly.
    private func isHeartRateAnomaly(_ bpm: Double) -> Bool {
        if bpm > Self.tachycardiaThreshold { return true }
        if bpm < Self.bradycardiaThreshold { return true }
        if let prevAvg = previousMinuteAvgBPM, abs(bpm - prevAvg) > Self.spikeThreshold {
            return true
        }
        return false
    }

    /// Return a human-readable reason string for the anomaly.
    private func anomalyReason(_ bpm: Double) -> String {
        if bpm > Self.tachycardiaThreshold { return "tachycardia" }
        if bpm < Self.bradycardiaThreshold { return "bradycardia" }
        if let prevAvg = previousMinuteAvgBPM, abs(bpm - prevAvg) > Self.spikeThreshold {
            let delta = bpm - prevAvg
            return delta > 0 ? "sudden_increase" : "sudden_decrease"
        }
        return "unknown"
    }

    /// Emit a single aggregated HR event if at least 60 seconds have passed
    /// since the last emit and the buffer is non-empty.
    private func emitAggregatedHeartRateIfReady(source: String) {
        let now = Date()

        // First call ever — just set the timer, don't emit yet
        if lastHREmitTime == nil {
            lastHREmitTime = now
            // If buffer already has data on first fetch, emit it
            guard !hrBuffer.isEmpty else { return }
        }

        guard let lastEmit = lastHREmitTime,
              now.timeIntervalSince(lastEmit) >= Self.hrEmitInterval,
              !hrBuffer.isEmpty else {
            return
        }

        let avg = hrBuffer.reduce(0, +) / Double(hrBuffer.count)
        let minBPM = hrBuffer.min() ?? avg
        let maxBPM = hrBuffer.max() ?? avg
        let count = hrBuffer.count

        let event = SensingEvent(
            timestamp: now,
            modality: .heartRate,
            payload: [
                "bpm": String(format: "%.0f", avg),
                "min": String(format: "%.0f", minBPM),
                "max": String(format: "%.0f", maxBPM),
                "count": "\(count)",
                "source": source
            ]
        )
        onEvent?(event)

        // Update rolling state
        previousMinuteAvgBPM = avg
        hrBuffer.removeAll()
        lastHREmitTime = now
    }

    /// Fetch most recent HRV samples (last hour).
    private func fetchHRV() {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let predicate = HKQuery.predicateForSamples(withStart: oneHourAgo, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: hrvType,
            predicate: predicate,
            limit: 3,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let samples = samples as? [HKQuantitySample], error == nil else { return }
            for sample in samples {
                let sdnn = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                let event = SensingEvent(
                    timestamp: sample.startDate,
                    modality: .hrv,
                    payload: [
                        "sdnn": String(format: "%.1f", sdnn),
                        "source": sample.sourceRevision.source.name
                    ]
                )
                self?.onEvent?(event)
            }
        }
        healthStore?.execute(query)
    }

    /// Fetch sleep analysis from the last 24 hours.
    private func fetchSleep() {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let yesterday = Date().addingTimeInterval(-86400)
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: 20,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let samples = samples as? [HKCategorySample], error == nil else { return }
            for sample in samples {
                let stage = Self.sleepStageString(from: sample.value)
                let formatter = ISO8601DateFormatter()
                let event = SensingEvent(
                    timestamp: sample.startDate,
                    modality: .sleep,
                    payload: [
                        "stage": stage,
                        "startDate": formatter.string(from: sample.startDate),
                        "endDate": formatter.string(from: sample.endDate),
                        "source": sample.sourceRevision.source.name
                    ]
                )
                self?.onEvent?(event)
            }
        }
        healthStore?.execute(query)
    }

    /// Fetch workouts completed in the last 24 hours.
    private func fetchWorkouts() {
        let yesterday = Date().addingTimeInterval(-86400)
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: HKWorkoutType.workoutType(),
            predicate: predicate,
            limit: 10,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let samples = samples as? [HKWorkout], error == nil else { return }
            for workout in samples {
                let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                let event = SensingEvent(
                    timestamp: workout.startDate,
                    modality: .workout,
                    payload: [
                        "type": Self.workoutTypeString(from: workout.workoutActivityType),
                        "duration": String(format: "%.0f", workout.duration),
                        "calories": calories.map { String(format: "%.0f", $0) } ?? "unknown",
                        "source": workout.sourceRevision.source.name
                    ]
                )
                self?.onEvent?(event)
            }
        }
        healthStore?.execute(query)
    }

    /// Fetch active energy burned in the last hour and aggregate into a single hourly event.
    ///
    /// Apple Watch writes many small active energy samples (~every few minutes).
    /// Instead of emitting each one, we buffer them and emit a single aggregated
    /// event once per hour with total kcal for that period.
    private func fetchActiveEnergy() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let predicate = HKQuery.predicateForSamples(withStart: oneHourAgo, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self, let samples = samples as? [HKQuantitySample], error == nil else { return }
            let source = samples.first?.sourceRevision.source.name ?? "watch"

            for sample in samples {
                let kcal = sample.quantity.doubleValue(for: .kilocalorie())
                self.activeEnergyBuffer.append(kcal)
            }

            self.emitAggregatedActiveEnergyIfReady(source: source)
        }
        healthStore?.execute(query)
    }

    /// Emit a single aggregated active energy event if at least 1 hour has passed.
    private func emitAggregatedActiveEnergyIfReady(source: String) {
        let now = Date()

        if lastActiveEnergyEmitTime == nil {
            lastActiveEnergyEmitTime = now
            guard !activeEnergyBuffer.isEmpty else { return }
        }

        guard let lastEmit = lastActiveEnergyEmitTime,
              now.timeIntervalSince(lastEmit) >= Self.activeEnergyEmitInterval,
              !activeEnergyBuffer.isEmpty else {
            return
        }

        let totalKcal = activeEnergyBuffer.reduce(0, +)

        let event = SensingEvent(
            timestamp: now,
            modality: .activeEnergy,
            payload: [
                "kcal": String(format: "%.0f", totalKcal),
                "samples": "\(activeEnergyBuffer.count)",
                "source": source
            ]
        )
        onEvent?(event)

        activeEnergyBuffer.removeAll()
        lastActiveEnergyEmitTime = now
    }

    /// Fetch basal (resting) energy burned in the last hour.
    private func fetchBasalEnergy() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else { return }
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let predicate = HKQuery.predicateForSamples(withStart: oneHourAgo, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: 5,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let samples = samples as? [HKQuantitySample], error == nil else { return }
            for sample in samples {
                let kcal = sample.quantity.doubleValue(for: .kilocalorie())
                let event = SensingEvent(
                    timestamp: sample.startDate,
                    modality: .basalEnergy,
                    payload: [
                        "kcal": String(format: "%.1f", kcal),
                        "source": sample.sourceRevision.source.name
                    ]
                )
                self?.onEvent?(event)
            }
        }
        healthStore?.execute(query)
    }

    /// Fetch respiratory rate samples from the last hour.
    private func fetchRespiratoryRate() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return }
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let predicate = HKQuery.predicateForSamples(withStart: oneHourAgo, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: 5,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let samples = samples as? [HKQuantitySample], error == nil else { return }
            for sample in samples {
                let breathsPerMin = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                let event = SensingEvent(
                    timestamp: sample.startDate,
                    modality: .respiratoryRate,
                    payload: [
                        "breathsPerMin": String(format: "%.1f", breathsPerMin),
                        "source": sample.sourceRevision.source.name
                    ]
                )
                self?.onEvent?(event)
            }
        }
        healthStore?.execute(query)
    }

    /// Fetch blood oxygen (SpO2) samples from the last hour.
    private func fetchBloodOxygen() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return }
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let predicate = HKQuery.predicateForSamples(withStart: oneHourAgo, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: 5,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let samples = samples as? [HKQuantitySample], error == nil else { return }
            for sample in samples {
                let percentage = sample.quantity.doubleValue(for: HKUnit.percent()) * 100
                let event = SensingEvent(
                    timestamp: sample.startDate,
                    modality: .bloodOxygen,
                    payload: [
                        "spo2": String(format: "%.1f", percentage),
                        "source": sample.sourceRevision.source.name
                    ]
                )
                self?.onEvent?(event)
            }
        }
        healthStore?.execute(query)
    }

    /// Fetch environmental audio exposure (noise level) from the last hour.
    private func fetchNoiseExposure() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure) else { return }
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let predicate = HKQuery.predicateForSamples(withStart: oneHourAgo, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: 5,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let samples = samples as? [HKQuantitySample], error == nil else { return }
            for sample in samples {
                let decibels = sample.quantity.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel())
                let event = SensingEvent(
                    timestamp: sample.startDate,
                    modality: .noiseExposure,
                    payload: [
                        "decibels": String(format: "%.1f", decibels),
                        "source": sample.sourceRevision.source.name
                    ]
                )
                self?.onEvent?(event)
            }
        }
        healthStore?.execute(query)
    }

    // MARK: - Helpers

    /// Convert a sleep analysis value to a human-readable string.
    private static func sleepStageString(from value: Int) -> String {
        switch value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            return "inBed"
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
            return "asleep"
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            return "awake"
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            return "core"
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            return "deep"
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            return "rem"
        default:
            return "unknown"
        }
    }

    /// Convert an HKWorkoutActivityType to a human-readable string.
    private static func workoutTypeString(from type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "running"
        case .walking: return "walking"
        case .cycling: return "cycling"
        case .swimming: return "swimming"
        case .yoga: return "yoga"
        case .functionalStrengthTraining: return "strength"
        case .traditionalStrengthTraining: return "strength"
        case .highIntensityIntervalTraining: return "hiit"
        case .elliptical: return "elliptical"
        case .rowing: return "rowing"
        case .stairClimbing: return "stairs"
        case .hiking: return "hiking"
        default: return "other"
        }
    }
}
