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

    /// Timer that periodically flushes aggregation buffers and refetches gap data.
    private var periodicFlushTimer: Timer?

    /// Interval for periodic buffer flush and gap refetch (2 minutes).
    private static let periodicFlushInterval: TimeInterval = 120

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

    // MARK: - Last Fetch Timestamps (persisted across launches)

    /// UserDefaults keys for per-type last fetch timestamps.
    private enum FetchKey {
        static let heartRate = "bobo_health_lastFetch_heartRate"
        static let hrv = "bobo_health_lastFetch_hrv"
        static let sleep = "bobo_health_lastFetch_sleep"
        static let workout = "bobo_health_lastFetch_workout"
        static let activeEnergy = "bobo_health_lastFetch_activeEnergy"
        static let basalEnergy = "bobo_health_lastFetch_basalEnergy"
        static let respiratoryRate = "bobo_health_lastFetch_respiratoryRate"
        static let bloodOxygen = "bobo_health_lastFetch_bloodOxygen"
        static let noiseExposure = "bobo_health_lastFetch_noiseExposure"
    }

    /// Default lookback on first-ever fetch (24 hours).
    private static let defaultLookback: TimeInterval = 86400

    /// Get the start date for a fetch: last fetch time or 24h ago on first run.
    private func fetchStart(for key: String) -> Date {
        let ts = UserDefaults.standard.double(forKey: key)
        if ts > 0 {
            return Date(timeIntervalSince1970: ts)
        }
        return Date().addingTimeInterval(-Self.defaultLookback)
    }

    /// Record that we just fetched up to now for a given key.
    private func recordFetch(for key: String) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
    }

    // MARK: - Anomaly Thresholds

    /// Resting heart rate above this is considered tachycardia.
    private static let tachycardiaThreshold: Double = 100

    /// Heart rate below this is considered bradycardia.
    private static let bradycardiaThreshold: Double = 45

    /// A jump larger than this from the previous minute's average triggers an anomaly.
    private static let spikeThreshold: Double = 30

    /// The HealthKit data types BOBO requests read access for.
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
        guard !isRunning else {
            print("[HealthSensor] Already running, skipping start")
            return
        }
        guard let healthStore else {
            print("[HealthSensor] HealthKit not available on this device")
            return
        }
        isRunning = true
        print("[HealthSensor] Starting — requesting authorization for \(Self.readTypes.count) types")

        healthStore.requestAuthorization(toShare: nil, read: Self.readTypes as Set<HKObjectType>) { [weak self] success, error in
            print("[HealthSensor] Authorization callback: success=\(success), error=\(error?.localizedDescription ?? "none")")
            if success {
                self?.enableBackgroundDelivery()
                self?.startObservers()
                self?.fetchRecentSamples()
                self?.startPeriodicFlush()
                print("[HealthSensor] All observers + fetch started")
            } else {
                print("[HealthSensor] Authorization failed: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }

    /// Called when app returns to foreground. Re-fetches all data types to cover any
    /// gap from background suspension. Observer queries may have gone stale, so we
    /// also restart them. This ensures the timeline is complete regardless of how
    /// long the app was in the background.
    func resume() {
        guard isRunning else { return }
        print("[HealthSensor] Resuming — backfilling gap data")
        fetchRecentSamples()
    }

    /// Stop all observer queries, cancel the periodic timer, and clear throttling state.
    func stop() {
        guard isRunning, let healthStore else { return }
        isRunning = false
        periodicFlushTimer?.invalidate()
        periodicFlushTimer = nil
        for query in observerQueries {
            healthStore.stop(query)
        }
        observerQueries.removeAll()

        // Flush any remaining buffered data before stopping
        if !hrBuffer.isEmpty {
            emitAggregatedHeartRateIfReady(source: "watch")
        }
        if !activeEnergyBuffer.isEmpty {
            emitAggregatedActiveEnergyIfReady(source: "watch")
        }

        // Reset throttling state
        hrBuffer.removeAll()
        lastHREmitTime = nil
        previousMinuteAvgBPM = nil
        activeEnergyBuffer.removeAll()
        lastActiveEnergyEmitTime = nil
    }

    // MARK: - Background Delivery

    /// Enable HealthKit background delivery for all monitored types.
    /// This allows HealthKit to wake the app when new samples arrive,
    /// even when the app is suspended. Observer queries then fire and
    /// data flows into the timeline.
    private func enableBackgroundDelivery() {
        guard let healthStore else { return }
        for type in Self.readTypes {
            healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                if !success {
                    print("[HealthSensor] Background delivery failed for \(type): \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
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

    /// Start a repeating timer that flushes aggregation buffers and refetches gap data.
    /// This ensures events are emitted even when HKObserverQuery doesn't fire
    /// (e.g., Watch temporarily off wrist, HealthKit delivery delays).
    private func startPeriodicFlush() {
        periodicFlushTimer?.invalidate()
        DispatchQueue.main.async { [weak self] in
            self?.periodicFlushTimer = Timer.scheduledTimer(
                withTimeInterval: Self.periodicFlushInterval,
                repeats: true
            ) { [weak self] _ in
                guard let self, self.isRunning else { return }
                // Flush buffered aggregations
                self.emitAggregatedHeartRateIfReady(source: "watch")
                self.emitAggregatedActiveEnergyIfReady(source: "watch")
                // Refetch all types to capture any gap data
                self.fetchRecentSamples()
            }
        }
    }

    /// Fetch heart rate samples since last fetch and emit per-minute aggregates.
    ///
    /// Samples are grouped by calendar minute. Completed minutes emit immediately
    /// as aggregated events (avg/min/max/count). The current (incomplete) minute
    /// is buffered and flushed by the periodic timer or next fetch cycle.
    /// Anomalies bypass aggregation and emit individually.
    private func fetchHeartRate() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let start = fetchStart(for: FetchKey.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let fetchKey = FetchKey.heartRate
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            if let error {
                print("[HealthSensor] HR fetch error: \(error.localizedDescription)")
            }
            guard let self, let samples = samples as? [HKQuantitySample], error == nil else { return }
            print("[HealthSensor] HR fetch returned \(samples.count) samples")
            guard !samples.isEmpty else {
                self.recordFetch(for: fetchKey)
                return
            }
            let source = samples.first?.sourceRevision.source.name ?? "watch"
            let calendar = Calendar.current

            // Current calendar minute — samples in this minute go to buffer (incomplete)
            let now = Date()
            let currentMinuteComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            let currentMinuteStart = calendar.date(from: currentMinuteComps) ?? now

            // Group samples by calendar minute, separate anomalies
            var minuteGroups: [Date: [Double]] = [:]
            for sample in samples {
                let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))

                // Anomaly — emit immediately regardless of grouping
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
                    print("[HealthSensor] Emitting HR anomaly: bpm=\(bpm)")
                    self.onEvent?(event)
                    continue
                }

                // Group by minute start
                let sampleMinuteComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: sample.startDate)
                let minuteStart = calendar.date(from: sampleMinuteComps) ?? sample.startDate
                minuteGroups[minuteStart, default: []].append(bpm)
            }

            // Emit completed minutes immediately, buffer current minute
            for (minute, bpms) in minuteGroups {
                if minute >= currentMinuteStart {
                    // Current (incomplete) minute — add to buffer
                    self.hrBuffer.append(contentsOf: bpms)
                } else {
                    // Completed minute — emit aggregated event now
                    let avg = bpms.reduce(0, +) / Double(bpms.count)
                    let event = SensingEvent(
                        timestamp: minute,
                        modality: .heartRate,
                        payload: [
                            "bpm": String(format: "%.0f", avg),
                            "min": String(format: "%.0f", bpms.min() ?? avg),
                            "max": String(format: "%.0f", bpms.max() ?? avg),
                            "count": "\(bpms.count)",
                            "source": source
                        ]
                    )
                    print("[HealthSensor] Emitting HR aggregate: avg=\(String(format: "%.0f", avg)) bpm, count=\(bpms.count)")
                    self.onEvent?(event)
                    self.previousMinuteAvgBPM = avg
                }
            }

            // Try flushing the current-minute buffer if enough time elapsed
            self.emitAggregatedHeartRateIfReady(source: source)
            self.recordFetch(for: fetchKey)
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

    /// Fetch HRV samples since last fetch (gap-aware).
    private func fetchHRV() {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        let start = fetchStart(for: FetchKey.hrv)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let fetchKey = FetchKey.hrv
        let query = HKSampleQuery(
            sampleType: hrvType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self, let samples = samples as? [HKQuantitySample], error == nil else { return }
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
                self.onEvent?(event)
            }
            self.recordFetch(for: fetchKey)
        }
        healthStore?.execute(query)
    }

    /// Fetch sleep analysis since last fetch (gap-aware).
    private func fetchSleep() {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let start = fetchStart(for: FetchKey.sleep)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let fetchKey = FetchKey.sleep
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self, let samples = samples as? [HKCategorySample], error == nil else { return }
            let formatter = ISO8601DateFormatter()
            for sample in samples {
                let stage = Self.sleepStageString(from: sample.value)
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
                self.onEvent?(event)
            }
            self.recordFetch(for: fetchKey)
        }
        healthStore?.execute(query)
    }

    /// Fetch workouts since last fetch (gap-aware).
    private func fetchWorkouts() {
        let start = fetchStart(for: FetchKey.workout)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let fetchKey = FetchKey.workout
        let query = HKSampleQuery(
            sampleType: HKWorkoutType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self, let samples = samples as? [HKWorkout], error == nil else { return }
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
                self.onEvent?(event)
            }
            self.recordFetch(for: fetchKey)
        }
        healthStore?.execute(query)
    }

    /// Fetch active energy since last fetch (gap-aware), grouped by 5-minute windows.
    ///
    /// Apple Watch writes many small active energy samples. Instead of emitting each one,
    /// samples are grouped by 5-minute calendar windows. Completed windows emit immediately;
    /// the current (incomplete) window stays in the buffer for periodic flush.
    private func fetchActiveEnergy() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let start = fetchStart(for: FetchKey.activeEnergy)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let fetchKey = FetchKey.activeEnergy
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self, let samples = samples as? [HKQuantitySample], error == nil else { return }
            guard !samples.isEmpty else {
                self.recordFetch(for: fetchKey)
                return
            }
            let source = samples.first?.sourceRevision.source.name ?? "watch"
            let calendar = Calendar.current

            // Current 5-minute window start
            let now = Date()
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            let currentWindowMinute = (comps.minute ?? 0) / 5 * 5
            var currentWindowComps = comps
            currentWindowComps.minute = currentWindowMinute
            let currentWindowStart = calendar.date(from: currentWindowComps) ?? now

            // Group samples by 5-minute window
            var windowGroups: [Date: Double] = [:]
            for sample in samples {
                let kcal = sample.quantity.doubleValue(for: .kilocalorie())
                let sComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: sample.startDate)
                let windowMinute = (sComps.minute ?? 0) / 5 * 5
                var windowComps = sComps
                windowComps.minute = windowMinute
                let windowStart = calendar.date(from: windowComps) ?? sample.startDate
                windowGroups[windowStart, default: 0] += kcal
            }

            // Emit completed windows immediately, buffer current window
            for (windowStart, totalKcal) in windowGroups {
                if windowStart >= currentWindowStart {
                    // Current window — add to buffer
                    self.activeEnergyBuffer.append(totalKcal)
                } else {
                    // Completed window — emit now
                    let event = SensingEvent(
                        timestamp: windowStart,
                        modality: .activeEnergy,
                        payload: [
                            "kcal": String(format: "%.0f", totalKcal),
                            "source": source
                        ]
                    )
                    self.onEvent?(event)
                }
            }

            // Try flushing the current-window buffer
            self.emitAggregatedActiveEnergyIfReady(source: source)
            self.recordFetch(for: fetchKey)
        }
        healthStore?.execute(query)
    }

    /// Flush the active energy buffer if enough time has elapsed since last emit.
    private func emitAggregatedActiveEnergyIfReady(source: String) {
        let now = Date()

        if lastActiveEnergyEmitTime == nil {
            lastActiveEnergyEmitTime = now
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
                "source": source
            ]
        )
        onEvent?(event)

        activeEnergyBuffer.removeAll()
        lastActiveEnergyEmitTime = now
    }

    /// Fetch basal (resting) energy burned since last fetch (gap-aware).
    private func fetchBasalEnergy() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else { return }
        let start = fetchStart(for: FetchKey.basalEnergy)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let fetchKey = FetchKey.basalEnergy
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self, let samples = samples as? [HKQuantitySample], error == nil else { return }
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
                self.onEvent?(event)
            }
            self.recordFetch(for: fetchKey)
        }
        healthStore?.execute(query)
    }

    /// Fetch respiratory rate since last fetch (gap-aware).
    private func fetchRespiratoryRate() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return }
        let start = fetchStart(for: FetchKey.respiratoryRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let fetchKey = FetchKey.respiratoryRate
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self, let samples = samples as? [HKQuantitySample], error == nil else { return }
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
                self.onEvent?(event)
            }
            self.recordFetch(for: fetchKey)
        }
        healthStore?.execute(query)
    }

    /// Fetch blood oxygen (SpO2) since last fetch (gap-aware).
    private func fetchBloodOxygen() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return }
        let start = fetchStart(for: FetchKey.bloodOxygen)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let fetchKey = FetchKey.bloodOxygen
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self, let samples = samples as? [HKQuantitySample], error == nil else { return }
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
                self.onEvent?(event)
            }
            self.recordFetch(for: fetchKey)
        }
        healthStore?.execute(query)
    }

    /// Fetch noise exposure since last fetch (gap-aware).
    private func fetchNoiseExposure() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure) else { return }
        let start = fetchStart(for: FetchKey.noiseExposure)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let fetchKey = FetchKey.noiseExposure
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self, let samples = samples as? [HKQuantitySample], error == nil else { return }
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
                self.onEvent?(event)
            }
            self.recordFetch(for: fetchKey)
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
