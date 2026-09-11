import SwiftUI
import SwiftData
import Foundation

struct MatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Match> { $0.isCompleted == false }) private var activeMatches: [Match]
    
    @State private var configuration = MatchConfiguration()
    @State private var selectedP1: Player?
    @State private var selectedP2: Player?
    @State private var location = ""
    @State private var showingSetup = false
    @State private var pendingPlayer: Player?
    
    @State private var matchForResults: Match?
    @State private var showingResults = false
    
    var currentMatch: Match? { activeMatches.first }

    var body: some View {
        ZStack {
            Color.courtDark.ignoresSafeArea()
            if let match = currentMatch {
                VStack(spacing: 0) {
                    mainScoreboard(match)
                    ScrollView {
                        VStack(spacing: 25) {
                            Text("ADD POINT").font(.caption).bold().foregroundStyle(.secondary).padding(.top, 20)
                            HStack(spacing: 15) {
                                playerActionCard(player: match.playerOne, color: .mintAccent)
                                playerActionCard(player: match.playerTwo, color: .orangeAccent)
                            }.padding(.horizontal)
                            liveTicker(match)
                            
                            HStack {
                                Button(role: .destructive) {
                                    if let m = currentMatch { modelContext.delete(m) }
                                } label: {
                                    Label("Reset", systemImage: "arrow.counterclockwise").padding().background(Color.white.opacity(0.05)).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 15))
                                }
                                
                                Button {
                                    undoPoint(match: match)
                                } label: {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .padding(.trailing, 10)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                        }
                    }
                }
            } else {
                emptyStateUI
            }
        }
        .sheet(isPresented: $showingSetup) { MatchSetupView(selectedP1: $selectedP1, selectedP2: $selectedP2, configuration: $configuration, location: $location, onStart: startNewMatch) }
        .sheet(item: $pendingPlayer) { player in
            PointEntryView(player: player) { outcome, note in recordPoint(player: player, outcome: outcome, note: note) }
        }
        .fullScreenCover(isPresented: $showingResults) {
            if let match = matchForResults {
                MatchResultsView(match: match, onStartNew: {
                    modelContext.delete(match)
                    matchForResults = nil
                    showingResults = false
                    selectedP1 = nil; selectedP2 = nil
                })
            }
        }
    }

    private var emptyStateUI: some View {
        VStack(spacing: 20) {
            Image(systemName: "tennisball.fill").font(.system(size: 80)).foregroundStyle(Color.mintAccent)
            Text("No Active Match").font(.title).bold().foregroundStyle(.white)
            Button("Start Match") {
                selectedP1 = nil
                selectedP2 = nil
                showingSetup = true
            }.buttonStyle(.borderedProminent).tint(.mintAccent).foregroundStyle(.black).controlSize(.large)
        }
    }

    private func mainScoreboard(_ match: Match) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("LIVE MATCH").font(.caption2).bold().tracking(2).foregroundStyle(Color.mintAccent)
                    Text(TennisEngine.getStatus(match: match, config: configuration)).font(.headline).foregroundStyle(.white)
                }
                Spacer()
                Button { showingSetup = true } label: { Image(systemName: "gearshape.fill").foregroundStyle(.white).padding(8).background(Color.white.opacity(0.1)).clipShape(Circle()) }
            }.padding().background(Color.black.opacity(0.3))
            HStack(alignment: .bottom) {
                Text(match.playerOne.name).font(.system(size: 22, weight: .black)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity, alignment: .trailing)
                Text("VS").font(.caption).bold().foregroundStyle(.secondary).padding(.horizontal, 15)
                Text(match.playerTwo.name).font(.system(size: 22, weight: .black)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.horizontal).padding(.top, 10)
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    scoreBox(value: "\(match.p1Sets)", label: "S", color: .mintAccent)
                    scoreBox(value: "\(match.p1Games)", label: "G", color: .mintAccent)
                    scoreBox(value: TennisEngine.calculateScore(match.p1Points, opponentPoints: match.p2Points, isTieBreak: match.isTieBreak, tieBreakPoints: match.tieBreakP1Points), label: "P", color: .mintAccent)
                }.frame(maxWidth: .infinity)
                Spacer().frame(width: 20)
                HStack(spacing: 8) {
                    scoreBox(value: TennisEngine.calculateScore(match.p2Points, opponentPoints: match.p1Points, isTieBreak: match.isTieBreak, tieBreakPoints: match.tieBreakP2Points), label: "P", color: .orangeAccent)
                    scoreBox(value: "\(match.p2Games)", label: "G", color: .orangeAccent)
                    scoreBox(value: "\(match.p2Sets)", label: "S", color: .orangeAccent)
                }.frame(maxWidth: .infinity)
            }.padding(.horizontal).padding(.vertical, 20)
        }.background(Color.black.opacity(0.4))
    }

    private func scoreBox(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 10, weight: .black)).foregroundStyle(color).padding(.horizontal, 4).padding(.vertical, 2).background(color.opacity(0.2)).clipShape(Capsule())
        }.frame(width: 45, height: 42).background(Color.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func playerActionCard(player: Player, color: Color) -> some View {
        VStack(spacing: 15) {
            Text(player.name.uppercased()).font(.caption).bold().foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity)
            Button { HapticManager.impact(.light); recordPoint(player: player, outcome: .winner, note: "") } label: {
                Label("Quick Point", systemImage: "plus.circle.fill").frame(maxWidth: .infinity).padding(.vertical, 12).background(color).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius: 12)).fontWeight(.bold)
            }
            Button { HapticManager.impact(.medium); pendingPlayer = player } label: {
                Label("Add Details", systemImage: "info.circle").frame(maxWidth: .infinity).padding(.vertical, 12).background(color.opacity(0.2)).foregroundStyle(color).clipShape(RoundedRectangle(cornerRadius: 12)).fontWeight(.semibold)
            }
        }.padding().frame(maxWidth: .infinity).background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.3), lineWidth: 1))
    }

    private func liveTicker(_ match: Match) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT POINTS").font(.caption).bold().tracking(1.5).foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 10) {
                ForEach(match.pointEvents.reversed().prefix(5)) { event in
                    let accentColor = event.player == match.playerOne ? Color.mintAccent : Color.orangeAccent
                    HStack(spacing: 4) {
                        Text(event.player.name.prefix(1)).bold().foregroundStyle(.black)
                        Image(systemName: event.outcome.icon).foregroundStyle(event.outcome.color).font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(LinearGradient(gradient: Gradient(colors: [accentColor, accentColor.opacity(0.8)]), startPoint: .top, endPoint: .bottom))
                    .clipShape(Capsule()).overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
            }.frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 20).padding(.horizontal)
        .background(LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0.2)]), startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private func startNewMatch(p1: Player, p2: Player) {
        let newMatch = Match(
            playerOne: p1,
            playerTwo: p2,
            format: configuration.formatText,
            location: location,
            setLength: configuration.setLength,
            tieBreakLength: configuration.tieBreakLength
        )
        modelContext.insert(newMatch)
        
        do {
            try modelContext.save()
            print("✅ Match saved successfully")
        } catch {
            print("❌ Database error: \(error.localizedDescription)")
        }
        
        ActivityManager.shared.startActivity(
            playerOne: p1.name,
            playerTwo: p2.name,
            p1Score: "Love",
            p2Score: "Love",
            p1Sets: 0,
            p2Sets: 0,
            p1Games: 0,
            p2Games: 0,
            isTieBreak: false,
            status: "Set in progress"
        )
        showingSetup = false
    }

    private func recordPoint(player: Player, outcome: PointOutcome, note: String) {
        guard let match = currentMatch else { return }
        let event = PointEvent(player: player, outcome: outcome, note: note)
        match.pointEvents.append(event)
        if player == match.playerOne { match.p1Points += 1; handleScoring(for: 1, match: match) } else { match.p2Points += 1; handleScoring(for: 2, match: match) }
        updateActivity(match: match)
    }
    
    private func undoPoint(match: Match) {
        guard let lastEvent = match.pointEvents.last else { return }
        match.pointEvents.removeLast()
        if lastEvent.player == match.playerOne { match.p1Points -= 1 } else { match.p2Points -= 1 }
        updateActivity(match: match)
        HapticManager.impact(.medium)
    }
    
    private func updateActivity(match: Match) {
        ActivityManager.shared.updateActivity(
            p1Score: TennisEngine.calculateScore(match.p1Points, opponentPoints: match.p2Points, isTieBreak: match.isTieBreak, tieBreakPoints: match.tieBreakP1Points),
            p2Score: TennisEngine.calculateScore(match.p2Points, opponentPoints: match.p1Points, isTieBreak: match.isTieBreak, tieBreakPoints: match.tieBreakP2Points),
            p1Sets: match.p1Sets, p2Sets: match.p2Sets, p1Games: match.p1Games, p2Games: match.p2Games, isTieBreak: match.isTieBreak,
            status: TennisEngine.getStatus(match: match, config: configuration)
        )
    }

    private func handleScoring(for player: Int, match: Match) {
        if match.isTieBreak {
            if player == 1 { match.tieBreakP1Points += 1 } else { match.tieBreakP2Points += 1 }
            if (match.tieBreakP1Points >= match.tieBreakLength && match.tieBreakP1Points >= match.tieBreakP2Points + 2) || (match.tieBreakP2Points >= match.tieBreakLength && match.tieBreakP2Points >= match.tieBreakP1Points + 2) { completeSet(winner: player == 1 ? 1 : 2, match: match) }
        } else {
            if player == 1 && match.p1Points >= 4 && match.p1Points >= match.p2Points + 2 { match.p1Games += 1; match.p1Points = 0; match.p2Points = 0; checkSetWinner(match: match) }
            else if player == 2 && match.p2Points >= 4 && match.p2Points >= match.p1Points + 2 { match.p2Games += 1; match.p1Points = 0; match.p2Points = 0; checkSetWinner(match: match) }
        }
    }
    
    private func checkSetWinner(match: Match) {
        if configuration.setTieBreak && match.p1Games == match.setLength - 1 && match.p2Games == match.setLength - 1 { match.isTieBreak = true }
        else if match.p1Games >= match.setLength && match.p1Games >= match.p2Games + 2 { completeSet(winner: 1, match: match) }
        else if match.p2Games >= match.setLength && match.p2Games >= match.p1Games + 2 { completeSet(winner: 2, match: match) }
    }
    
    private func completeSet(winner: Int, match: Match) {
        match.completedSets.append("\(match.p1Games)-\(match.p2Games)")
        if winner == 1 { match.p1Sets += 1 } else { match.p2Sets += 1 }
        match.p1Games = 0; match.p2Games = 0; match.p1Points = 0; match.p2Points = 0; match.isTieBreak = false
        if match.p1Sets >= configuration.setsToWin || match.p2Sets >= configuration.setsToWin {
            match.isCompleted = true
            let winnerName = winner == 1 ? match.playerOne.name : match.playerTwo.name
            let loserName = winner == 1 ? match.playerTwo.name : match.playerOne.name
            match.winnerName = winnerName
            match.setScores = match.completedSets.joined(separator: ", ")
            NotificationManager.shared.sendMatchEndNotification(winner: winnerName, loser: loserName)
            ActivityManager.shared.stopActivity()
            try? modelContext.save()
            matchForResults = match
            showingResults = true
        }
    }
}
