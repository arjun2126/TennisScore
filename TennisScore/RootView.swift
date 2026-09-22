import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var session = UserSessionManager.shared
    @State private var showingOnboarding = false
    @State private var showingProfileSetup = false
    @State private var deepLinkToken: String?
    @Query private var players: [Player]
    @Query private var matches: [Match]
    @Query private var events: [Event]
    
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
            PlayerListView(showsDoneButton: false).tabItem { Label("Rivals", systemImage: "person.2.fill") }
            TournamentView().tabItem { Label("Tournaments", systemImage: "trophy.fill") }
            StatsView().tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            MoreTabView().tabItem { Label("More", systemImage: "ellipsis.circle") }
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
            if phase == .active {
                NotificationCenter.default.post(
                    name: WatchBridge.watchActionNotification,
                    object: nil,
                    userInfo: ["action": "requestState"]
                )
                let activeMatch = matches.first { !$0.isCompleted }
                let matchEntry: WidgetFeed.MatchEntry? = activeMatch.map { m in
                    let p1Score = TennisEngine.calculateScore(points: m.p1Points, opponentPoints: m.p2Points, isTieBreak: m.isTieBreak, tieBreakPoints: m.tieBreakP1Points)
                    let p2Score = TennisEngine.calculateScore(points: m.p2Points, opponentPoints: m.p1Points, isTieBreak: m.isTieBreak, tieBreakPoints: m.tieBreakP2Points)
                    return WidgetFeed.MatchEntry(
                        playerOne: m.playerOne.name, playerTwo: m.playerTwo.name,
                        p1Score: p1Score, p2Score: p2Score,
                        p1Sets: m.p1Sets, p2Sets: m.p2Sets,
                        isTieBreak: m.isTieBreak,
                        date: m.date ?? .now, isActive: !m.isCompleted
                    )
                }
                let upcoming = events.filter { $0.startDate > Date() && $0.startDate < Date().addingTimeInterval(7 * 86400) }
                    .map { WidgetFeed.EventEntry(name: $0.name, location: $0.locationLabel, startDate: $0.startDate) }
                WidgetFeed.shared.write(activeMatch: matchEntry, upcoming: upcoming)
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
