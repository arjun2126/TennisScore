import SwiftUI
import SwiftData
import Charts

struct PlayerProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let player: Player
    let matches: [Match]
    
    private var playerMatches: [Match] { matches.filter { $0.playerOne == player || $0.playerTwo == player } }
    private var totalWins: Int { playerMatches.filter { $0.winnerName == player.name }.count }
    private var winRate: Double { playerMatches.isEmpty ? 0 : (Double(totalWins) / Double(playerMatches.count)) * 100 }
    private var allPoints: [PointEvent] { playerMatches.flatMap { $0.pointEvents }.filter { $0.player == player } }

    var body: some View {
        ZStack {
            Color.courtDark.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 25) {
                    headerSection
                    dnaSection
                    historySection
                    
                    Button(role: .destructive) {
                        modelContext.delete(player)
                        dismiss()
                    } label: {
                        Label("Delete Player Profile", systemImage: "trash")
                            .font(.footnote).bold().padding().foregroundStyle(.red)
                    }
                    .padding(.top, 20)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("CAREER ANALYTICS").font(.caption).bold().tracking(3).foregroundStyle(Color.mintAccent)
                Text(player.name).font(.system(size: 28, weight: .black)).foregroundStyle(.white)
            }.frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 20) {
                statItem(label: "MATCHES", value: "\(playerMatches.count)")
                statItem(label: "WINS", value: "\(totalWins)")
                statItem(label: "WIN RATE", value: String(format: "%.1f%%", winRate))
            }
            .padding().background(Color.black.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.mintAccent.opacity(0.3), lineWidth: 1))
        }.padding(.horizontal)
    }
    
    private var dnaSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("POINT DNA").font(.caption).bold().tracking(2).foregroundStyle(.secondary)
            Chart {
                BarMark(x: .value("Type", "Aces"), y: .value("Count", count(for: .ace))).foregroundStyle(.yellow)
                BarMark(x: .value("Type", "Winners"), y: .value("Count", events(for: .winner).count)).foregroundStyle(.green)
                BarMark(x: .value("Type", "Forced E"), y: .value("Count", events(for: .forcedError).count)).foregroundStyle(.blue)
                BarMark(x: .value("Type", "Unforced E"), y: .value("Count", events(for: .unforcedError).count)).foregroundStyle(.red)
            }
            .frame(height: 150).foregroundStyle(.white).chartYAxis(.hidden)
            Text("Yellow: Aces | Green: Winners | Blue: Forced | Red: Unforced").font(.system(size: 10)).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
        .padding().background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal)
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("MATCH HISTORY").font(.caption).bold().tracking(2).foregroundStyle(.secondary)
            ForEach(playerMatches.sorted(by: { $0.date > $1.date })) { match in
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(match.playerOne.name) vs \(match.playerTwo.name)").font(.subheadline).foregroundStyle(.white)
                        Text(match.setScores).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(match.winnerName == player.name ? "WON" : "LOST").font(.caption2).bold().padding(.horizontal, 8).padding(.vertical, 4).background(match.winnerName == player.name ? Color.mintAccent.opacity(0.2) : Color.red.opacity(0.2)).foregroundStyle(match.winnerName == player.name ? Color.mintAccent : .red).clipShape(Capsule())
                }
                .padding().background(Color.black.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }.padding(.horizontal)
    }
    
    private func statItem(label: String, value: String) -> some View {
        VStack {
            Text(value).font(.title2).bold().foregroundStyle(.white)
            Text(label).font(.caption2).bold().foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
    private func count(for outcome: PointOutcome) -> Int { allPoints.filter { $0.outcome == outcome }.count }
    private func events(for outcome: PointOutcome) -> [PointEvent] { allPoints.filter { $0.outcome == outcome } }
}
