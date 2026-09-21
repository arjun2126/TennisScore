import Foundation
import Combine
import HealthKit

/// Records a HealthKit tennis workout for wrist-started matches.
///
/// Enhancement only: scoring never depends on it. Every failure path is
/// logged, never thrown, so a denied permission or missing sensor can never
/// break the match loop.
@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    static let shared = WatchWorkoutManager()

    @Published private(set) var isRunning = false
    /// Live biometric telemetry (0 when unavailable/denied).
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var activeCalories: Double = 0

    /// Running mean inputs for Average Match Heart Rate.
    private var heartRateSum = 0.0
    private var heartRateCount = 0
    var averageHeartRate: Double {
        heartRateCount == 0 ? 0 : heartRateSum / Double(heartRateCount)
    }

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var energyQuery: HKAnchoredObjectQuery?

    private override init() {
        super.init()
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let workout = HKObjectType.workoutType()
        var read: Set<HKObjectType> = [workout]
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            read.insert(heartRate)
        }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            read.insert(energy)
        }
        healthStore.requestAuthorization(toShare: [workout], read: read) { granted, error in
            print("⌚️ HealthKit authorization: granted=\(granted) error=\(error?.localizedDescription ?? "none")")
        }
    }

    /// Starts a `.tennis` workout. Ends any stale session first (never stack).
    func startTennisWorkout() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        endWorkout()
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .tennis
        configuration.locationType = .unknown
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            let startDate = Date()
            session.startActivity(with: startDate)
            builder.beginCollection(withStart: startDate) { _, _ in }
            self.session = session
            self.builder = builder
            isRunning = true
            heartRate = 0
            activeCalories = 0
            heartRateSum = 0
            heartRateCount = 0
            startObserving(from: startDate)
            print("⌚️ Tennis workout STARTED at \(startDate) — verify in Health app: Browse > Activity > Workouts > Tennis")
        } catch {
            print("⌚️ Workout start failed: \(error.localizedDescription)")
        }
    }

    /// Ends the session and saves the workout. Idempotent.
    func endWorkout() {
        stopObserving()
        guard let session else {
            isRunning = false
            return
        }
        self.session = nil
        let builder = self.builder
        self.builder = nil
        session.end()
        print("⌚️ Tennis workout ENDED at \(Date()) — saving to Health app")
        // No self captures in these completions: isRunning already cleared
        // below, so there is nothing concurrent left to reference.
        builder?.endCollection(withEnd: Date()) { _, _ in
            builder?.finishWorkout { _, _ in
                print("⌚️ Tennis workout SAVED to Health app")
            }
        }
        isRunning = false
    }

    // MARK: - Live biometric telemetry (HKAnchoredObjectQuery)

    /// Observes real-time heart rate + active energy for the running workout.
    /// Fail-soft: denied permissions or missing sensors simply leave zeros.
    private func startObserving(from startDate: Date) {
        stopObserving()
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)

        let heartRateQuery = HKAnchoredObjectQuery(
            type: heartRateType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, anchor, _ in
            self?.handleHeartRate(samples: samples)
        }
        heartRateQuery.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.handleHeartRate(samples: samples)
        }
        self.heartRateQuery = heartRateQuery
        healthStore.execute(heartRateQuery)

        let energyQuery = HKAnchoredObjectQuery(
            type: energyType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.handleEnergy(samples: samples)
        }
        energyQuery.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.handleEnergy(samples: samples)
        }
        self.energyQuery = energyQuery
        healthStore.execute(energyQuery)
    }

    private func stopObserving() {
        if let heartRateQuery { healthStore.stop(heartRateQuery) }
        if let energyQuery { healthStore.stop(energyQuery) }
        heartRateQuery = nil
        energyQuery = nil
    }

    nonisolated private func handleHeartRate(samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else { return }
        let bpm = latest.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
        Task { @MainActor in
            self.heartRate = bpm
            self.heartRateSum += bpm
            self.heartRateCount += 1
        }
    }

    nonisolated private func handleEnergy(samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }
        let kcal = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .kilocalorie()) }
        Task { @MainActor in self.activeCalories += kcal }
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        print("⌚️ Workout session state: \(fromState.rawValue) -> \(toState.rawValue) at \(date)")
        if toState == .ended {
            Task { @MainActor in WatchWorkoutManager.shared.isRunning = false }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("⌚️ Workout session FAILED: \(error.localizedDescription)")
        Task { @MainActor in WatchWorkoutManager.shared.isRunning = false }
    }
}
