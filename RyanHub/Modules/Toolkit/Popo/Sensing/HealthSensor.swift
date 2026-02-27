import Foundation
import HealthKit

// MARK: - Health Sensor

/// Observes health data from HealthKit including heart rate, HRV, sleep,
/// and workout completions. Apple Watch data flows through HealthKit
/// automatically, so no special Watch code is needed.
///
/// Uses HKObserverQuery for background notifications on new data,
/// and HKSampleQuery for batch fetching recent samples.
final class HealthSensor {
    private let healthStore: HKHealthStore?
    private var observerQueries: [HKObserverQuery] = []
    private var isRunning = false

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

    /// Stop all observer queries.
    func stop() {
        guard isRunning, let healthStore else { return }
        isRunning = false
        for query in observerQueries {
            healthStore.stop(query)
        }
        observerQueries.removeAll()
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
    }

    // MARK: - Fetch Methods

    /// Fetch recent samples on startup for all monitored types.
    private func fetchRecentSamples() {
        fetchHeartRate()
        fetchHRV()
        fetchSleep()
        fetchWorkouts()
    }

    /// Fetch most recent heart rate samples (last 5 minutes).
    private func fetchHeartRate() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let predicate = HKQuery.predicateForSamples(withStart: fiveMinutesAgo, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 5,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let samples = samples as? [HKQuantitySample], error == nil else { return }
            for sample in samples {
                let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                let event = SensingEvent(
                    timestamp: sample.startDate,
                    modality: .heartRate,
                    payload: [
                        "bpm": String(format: "%.0f", bpm),
                        "source": sample.sourceRevision.source.name
                    ]
                )
                self?.onEvent?(event)
            }
        }
        healthStore?.execute(query)
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
