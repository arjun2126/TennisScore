import SwiftUI
import SwiftData

@main
struct VantageApp: App {
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        _ = NotificationManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            RootView().preferredColorScheme(.dark)
        }
        .modelContainer(for: [Match.self, PointEvent.self, Player.self, Tournament.self, TournamentMatch.self, League.self, LeagueMatch.self])
    }
}
