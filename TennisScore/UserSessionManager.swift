import Foundation
import Combine

/// First-launch routing state. Owns the two persistence flags; the routing
/// decision itself is a pure function (unit-tested headlessly).
enum AppScreen: Equatable {
    case onboarding
    case profileSetup
    case home
}

final class UserSessionManager: ObservableObject {
    static let shared = UserSessionManager()
    
    @Published var hasSeenOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: Self.onboardingKey) }
    }
    @Published var hasCompletedProfileSetup: Bool {
        didSet { UserDefaults.standard.set(hasCompletedProfileSetup, forKey: Self.profileKey) }
    }
    
    static let onboardingKey = "hasSeenOnboarding"
    static let profileKey = "hasCompletedProfileSetup"
    
    private init() {
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        self.hasCompletedProfileSetup = UserDefaults.standard.bool(forKey: Self.profileKey)
    }
    
    /// The mandatory path: Onboarding → ProfileSetup → Home.
    /// Home is reachable only with onboarding done AND (setup done OR a
    /// profile already in the store). Pure logic — no UI, no store access.
    static func nextScreen(hasSeenOnboarding: Bool, hasCompletedProfileSetup: Bool, storeHasUser: Bool) -> AppScreen {
        if !hasSeenOnboarding { return .onboarding }
        if !hasCompletedProfileSetup && !storeHasUser { return .profileSetup }
        return .home
    }
    
    func completeOnboarding() {
        hasSeenOnboarding = true
    }
    
    func completeProfileSetup() {
        hasCompletedProfileSetup = true
    }
}
