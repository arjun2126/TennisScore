import Foundation
import Combine
import HealthKit

/// Records a HealthKit tennis workout for iPhone-started matches, so users
/// without a Watch still see every match logged as a Workout in Health.
///
/// Enhancement only: scoring never depends on it. Every failure path is
/// logged, never thrown. Usage descriptions are required in the plist;
/// without them the manager safely no-ops instead of crashing.
@MainActor
final class PhoneWorkoutManager: NSObject, ObservableObject {
    static let shared = PhoneWorkoutManager()

    @Published private(set) var isRunning = false

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private override init() {
        super.init()
    }

    private var hasUsageDescriptions: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") != nil
            && Bundle.main.object(forInfoDictionaryKey: "NSHealthUpdateUsageDescription") != nil
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable(), hasUsageDescriptions else { return }
        let workout = HKObjectType.workoutType()
        healthStore.requestAuthorization(toShare: [workout], read: [workout]) { granted, error in
            print("📱 HealthKit authorization: granted=\(granted) error=\(error?.localizedDescription ?? "none")")
        }
    }

    /// Starts a `.tennis` workout. Ends any stale session first (never stack).
    func startTennisWorkout() {
        guard HKHealthStore.isHealthDataAvailable(), hasUsageDescriptions else { return }
        endWorkout()
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .tennis
        configuration.locationType = .unknown
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { _, _ in }
            self.session = session
            self.builder = builder
            isRunning = true
            print("📱 Tennis workout STARTED at \(Date()) — verify in Health app: Browse > Activity > Workouts > Tennis")
        } catch {
            print("📱 Workout start failed: \(error.localizedDescription)")
        }
    }

    /// Ends the session and saves the workout. Idempotent.
    func endWorkout() {
        guard let session else {
            isRunning = false
            return
        }
        self.session = nil
        let builder = self.builder
        self.builder = nil
        session.end()
        print("📱 Tennis workout ENDED at \(Date()) — saving to Health app")
        // No self captures in these completions: isRunning already cleared
        // below, so there is nothing concurrent left to reference.
        builder?.endCollection(withEnd: Date()) { _, _ in
            builder?.finishWorkout { _, _ in
                print("📱 Tennis workout SAVED to Health app")
            }
        }
        isRunning = false
    }
}

extension PhoneWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        print("📱 Workout session state: \(fromState.rawValue) -> \(toState.rawValue) at \(date)")
        if toState == .ended {
            Task { @MainActor in PhoneWorkoutManager.shared.isRunning = false }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("📱 Workout session FAILED: \(error.localizedDescription)")
        Task { @MainActor in PhoneWorkoutManager.shared.isRunning = false }
    }
}
