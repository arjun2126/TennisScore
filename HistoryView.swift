import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Match.date, order: .reverse) private var matches: [Match]
    var completedMatches: [Match] { matches.filter { $0.isCompleted } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.courtDark.ignoresSafeArea()
                if completedMatches.isEmpty {
                    ContentUnavailableView("No Matches", systemImage: "tennisball", description: Text("Completed matches will appear here.")).foregroundStyle(.white)
                } else {
                    List {
                        ForEach(completedMatches) { match in
                            NavigationLink(destination: MatchDetailView(match: match)) {
                                matchCard(match)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { modelContext.delete(match) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .foregroundStyle(.white)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Match History")
        }
    }

    private func matchCard(_ match: Match) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("\(match.playerOne.name) vs \(match.playerTwo.name)").font(.headline).foregroundStyle(.white)
                Text(match.setScores).font(.subheadline).foregroundStyle(Color.mintAccent)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(match.winnerName).font(.caption).bold().padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.mintAccent.opacity(0.2)).foregroundStyle(Color.mintAccent).clipShape(Capsule())
                Text(match.date, format: .dateTime.day().month().year()).font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.vertical, 8)
    }
}
