import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \Player.name) private var players: [Player]
    @Query private var matches: [Match]
    @State private var searchText = ""
    
    var filteredPlayers: [Player] {
        if searchText.isEmpty { return players }
        return players.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.courtDark.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 25) {
                        GlobalStatsHeader(matches: matches, playersCount: players.count)
                        
                        TextField("Search Players...", text: $searchText)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal)
                        
                        Text("PLAYER PROFILES").font(.caption).bold().tracking(2).foregroundStyle(.white.opacity(0.6)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                        
                        VStack(spacing: 15) {
                            ForEach(filteredPlayers) { player in
                                NavigationLink(destination: PlayerProfileView(player: player, matches: matches)) {
                                    PlayerPerformanceCard(player: player, matches: matches)
                                }
                                .buttonStyle(PlainButtonStyle()).padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Performance")
        }
    }
}

struct GlobalStatsHeader: View {
    let matches: [Match]
    let playersCount: Int
    var body: some View {
        HStack(spacing: 15) {
            statBox(title: "TOTAL MATCHES", value: "\(matches.filter { $0.isCompleted }.count)", color: .mintAccent)
            statBox(title: "TOTAL PLAYERS", value: "\(playersCount)", color: .blue)
        }
        .padding(.horizontal)
    }
    private func statBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value).font(.system(size: 28, weight: .black)).foregroundStyle(.white)
            Text(title).font(.system(size: 10, weight: .bold)).foregroundStyle(color).tracking(1)
        }
        .frame(maxWidth: .infinity).padding().background(Color.black.opacity(0.4)).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.4), lineWidth: 1))
    }
}

struct PlayerPerformanceCard: View {
    let player: Player
    let matches: [Match]
    var body: some View {
        let playerMatches = matches.filter { $0.playerOne == player || $0.playerTwo == player }
        let wins = playerMatches.filter { $0.winnerName == player.name }.count
        let winRate = playerMatches.isEmpty ? 0 : (Double(wins) / Double(playerMatches.count)) * 100
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name).font(.headline).foregroundStyle(.white)
                Text("\(playerMatches.count) Matches").font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            HStack(spacing: 10) {
                Text("\(wins)").bold().foregroundStyle(.white)
                Text("W").font(.caption2).bold().foregroundStyle(Color.mintAccent)
            }
            HStack(spacing: 10) {
                Text("\(Int(winRate))%").bold().foregroundStyle(.white)
                Text("WIN").font(.caption2).bold().foregroundStyle(Color.mintAccent)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.white.opacity(0.3))
        }
        .padding().background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
