import SwiftUI
import SwiftData

struct ManagePlayersView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Player.name) private var players: [Player]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.courtDark.ignoresSafeArea()
                if players.isEmpty {
                    ContentUnavailableView("No Players", systemImage: "person.slash", description: Text("Your player book is empty.")).foregroundStyle(.white)
                } else {
                    List {
                        ForEach(players) { player in
                            HStack {
                                Text(player.name).foregroundStyle(.white)
                                Spacer()
                                Text("\(player.matchesAsP1.count + player.matchesAsP2.count) Matches").font(.caption).foregroundStyle(.secondary)
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(player)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Player Book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
