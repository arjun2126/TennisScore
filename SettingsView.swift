import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingManagePlayers = false
    @State private var showingInstructions = false
    @State private var showingDeleteAll = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.courtDark.ignoresSafeArea()
                List {
                    Section(header: Text("Management").foregroundStyle(.white)) {
                        Button { showingManagePlayers = true } label: {
                            Label("Manage Player Book", systemImage: "person.badge.plus")
                        }
                        Button { showingInstructions = true } label: {
                            Label("Instructions", systemImage: "questionmark.circle")
                        }
                    }
                    Section(header: Text("Danger Zone").foregroundStyle(.white)) {
                        Button(role: .destructive) { showingDeleteAll = true } label: {
                            Label("Clear All Data", systemImage: "trash")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.courtDark)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingManagePlayers) { ManagePlayersView() }
            .sheet(isPresented: $showingInstructions) { OnboardingView() }
            .alert("Are you sure?", isPresented: $showingDeleteAll) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) { deleteAllData() }
            } message: {
                Text("This will permanently remove all players, matches, and stats.")
            }
        }
    }
    
    private func deleteAllData() {
        try? modelContext.delete(model: Match.self)
        try? modelContext.delete(model: Player.self)
        try? modelContext.delete(model: PointEvent.self)
        try? modelContext.save()
    }
}
