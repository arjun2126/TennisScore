import SwiftUI
import SwiftData

@main
struct TennisScoreApp: App {
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        _ = NotificationManager.shared
        NotificationManager.shared.requestPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView().preferredColorScheme(.dark)
        }
        .modelContainer(for: [Match.self, PointEvent.self, Player.self])
    }
}

struct RootView: View {
    // MOVE THE LOGIC HERE
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showingOnboarding = false

    var body: some View {
        TabView {
            MatchView().tabItem { Label("Score", systemImage: "tennisball.fill") }
            HistoryView().tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            StatsView().tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Color.mintAccent)
        .onAppear {
            // Only trigger if they haven't seen it
            if !hasSeenOnboarding {
                showingOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView()
        }
    }
}
