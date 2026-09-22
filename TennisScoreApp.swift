import SwiftUI
import SwiftData

@main
struct VantageApp: App {
    let container: ModelContainer

    init() {
        let appearance = UINavigationBarAppearance()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        _ = NotificationManager.shared

        let schema = Schema([
            Match.self, PointEvent.self, Player.self,
            Tournament.self, TournamentMatch.self,
            League.self, LeagueMatch.self,
            Event.self, EventRegistration.self, EventReport.self,
            PaymentRecord.self, PayoutRecord.self,
        ])
        do {
            container = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
        PaymentStore.shared.attach(container: container)
    }

    var body: some Scene {
        WindowGroup {
            RootView().preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
