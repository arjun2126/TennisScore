import SwiftUI

struct MatchDetailView: View {
    let match: Match

    var body: some View {
        ZStack {
            Color.courtDark.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 25) {
                    VStack(spacing: 15) {
                        HStack {
                            VStack {
                                Text(match.playerOne.name).font(.headline).foregroundStyle(.white)
                                Text("\(match.p1Sets)").font(.system(size: 30, weight: .black)).foregroundStyle(Color.mintAccent)
                            }
                            Spacer()
                            Text("VS").font(.caption).bold().foregroundStyle(.secondary)
                            Spacer()
                            VStack {
                                Text(match.playerTwo.name).font(.headline).foregroundStyle(.white)
                                Text("\(match.p2Sets)").font(.system(size: 30, weight: .black)).foregroundStyle(Color.orangeAccent)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        Text(match.setScores).font(.title3).bold().foregroundStyle(.white)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 15) {
                        Text("STATISTICS").font(.caption).bold().tracking(2).foregroundStyle(.secondary)
                        statComparisonRow(label: "Aces", p1: count(for: .ace, player: match.playerOne), p2: count(for: .ace, player: match.playerTwo))
                        statComparisonRow(label: "Winners", p1: count(for: .winner, player: match.playerOne), p2: count(for: .winner, player: match.playerTwo))
                        statComparisonRow(label: "Unforced Errors", p1: count(for: .unforcedError, player: match.playerOne), p2: count(for: .unforcedError, player: match.playerTwo))
                        statComparisonRow(label: "Forced Errors", p1: count(for: .forcedError, player: match.playerOne), p2: count(for: .forcedError, player: match.playerTwo))
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("MATCH NOTES").font(.caption).bold().tracking(2).foregroundStyle(.secondary)
                        let notes = match.pointEvents.filter { !$0.note.isEmpty }
                        if notes.isEmpty {
                            Text("No notes recorded").font(.subheadline).foregroundStyle(.secondary).italic()
                        } else {
                            ForEach(notes) { event in
                                HStack(alignment: .top) {
                                    Text("\(event.player.name.prefix(1))").bold().foregroundStyle(event.player == match.playerOne ? Color.mintAccent : Color.orangeAccent)
                                    Text(event.note).font(.subheadline).foregroundStyle(.white)
                                }
                                .padding(.vertical, 4)
                                Divider().background(Color.white.opacity(0.1))
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func count(for outcome: PointOutcome, player: Player) -> Int {
        match.pointEvents.filter { $0.player == player && $0.outcome == outcome }.count
    }

    private func statComparisonRow(label: String, p1: Int, p2: Int) -> some View {
        let total = p1 + p2
        let p1Width = total == 0 ? 0.5 : Double(p1) / Double(total)
        return VStack(spacing: 8) {
            Text(label).font(.caption).bold().foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 0) {
                ZStack(alignment: .trailing) {
                    Rectangle().fill(Color.mintAccent).frame(width: CGFloat(p1Width * 300), height: 12)
                    Text("\(p1)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white).padding(.trailing, 4)
                }
                Rectangle().fill(Color.white.opacity(0.1)).frame(width: 4, height: 12)
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.orangeAccent).frame(width: CGFloat((1 - p1Width) * 300), height: 12)
                    Text("\(p2)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white).padding(.leading, 4)
                }
            }
            .frame(width: 300).frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
