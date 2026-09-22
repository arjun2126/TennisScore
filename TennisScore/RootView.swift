import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var session = UserSessionManager.shared
    @State private var showingOnboarding = false
    @State private var showingProfileSetup = false
    @State private var deepLinkToken: String?
    @Query private var players: [Player]
    
    private var storeHasUser: Bool {
        players.contains(where: { $0.isCurrentUser })
    }
    
    /// Single routing funnel: Onboarding → ProfileSetup → Home.
    /// Deliberately change-driven (never bare-appear beyond onboarding) so a
    /// not-yet-loaded store can never false-trigger for existing users.
    private func route() {
        switch UserSessionManager.nextScreen(
            hasSeenOnboarding: session.hasSeenOnboarding,
            hasCompletedProfileSetup: session.hasCompletedProfileSetup,
            storeHasUser: storeHasUser
        ) {
        case .onboarding:
            showingOnboarding = true
        case .profileSetup:
            if !showingProfileSetup {
                showingProfileSetup = true
            }
        case .home:
            break
        }
    }

    var body: some View {
        TabView {
            MatchView().tabItem { Label("Score", systemImage: "tennisball.fill") }
            EventListView().tabItem { Label("Events", systemImage: "calendar") }
            CreatorDashboardView().tabItem { Label("Creator", systemImage: "banknote") }
            TournamentView().tabItem { Label("Tournaments", systemImage: "trophy.fill") }
            StatsView().tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            PlayerListView(showsDoneButton: false).tabItem { Label("Rivals", systemImage: "person.2.fill") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Color.mintAccent)
        .onOpenURL { url in
            if let token = EventLink.token(from: url) {
                deepLinkToken = token
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { deepLinkToken != nil },
                set: { if !$0 { deepLinkToken = nil } }
            )
        ) {
            if let token = deepLinkToken {
                EventDetailHostView(token: token)
                    .onDisappear { deepLinkToken = nil }
            }
        }
        .onAppear {
            // Only trigger if they haven't seen it
            if !session.hasSeenOnboarding {
                showingOnboarding = true
            }
            // Cold-start handshake: nudge the Score tab to push current
            // state to the Watch immediately (handled → state push).
            NotificationCenter.default.post(
                name: WatchBridge.watchActionNotification,
                object: nil,
                userInfo: ["action": "requestState"]
            )
        }
        .onChange(of: session.hasSeenOnboarding) { _, _ in
            route()
        }
        .onChange(of: players.map(\.isCurrentUser)) { _, _ in
            route()
        }
        .onChange(of: showingProfileSetup) { _, _ in
            // The gate is mandatory: no Home screen without a profile.
            route()
        }
        .onChange(of: scenePhase) { _, phase in
            // Heartbeat: every foreground entry nudges the Score tab to push
            // current state to the Watch immediately (handled → state push).
            if phase == .active {
                NotificationCenter.default.post(
                    name: WatchBridge.watchActionNotification,
                    object: nil,
                    userInfo: ["action": "requestState"]
                )
            }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView()
        }
        .fullScreenCover(isPresented: $showingProfileSetup) {
            ProfileSetupView(onComplete: {
                session.completeProfileSetup()
                showingProfileSetup = false
            })
        }
    }
}
