import SwiftUI

enum MoreDestination: Hashable {
    case events
    case creator
    case settings
}

struct MoreTabView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Create & manage") {
                    NavigationLink("Events", value: MoreDestination.events)
                    NavigationLink("Creator", value: MoreDestination.creator)
                }
                Section("Account") {
                    NavigationLink("Settings & Profile", value: MoreDestination.settings)
                }
            }
            .navigationTitle("More")
            .navigationDestination(for: MoreDestination.self) { dest in
                switch dest {
                case .events: EventListView()
                case .creator: CreatorDashboardView()
                case .settings: SettingsView()
                }
            }
        }
    }
}
