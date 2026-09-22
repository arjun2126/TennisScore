import Foundation
import SwiftData

// MARK: - League (season-long round-robin)

enum LeagueMatchStatus: String, Codable, Sendable {
    case pending
    case completed

    var title: String {
        switch self {
        case .pending: "Not Played"
        case .completed: "Complete"
        }
    }
}

/// A season-long round-robin league: a fixed roster that meets week by week.
/// Schedule math reuses `DrawEngine.roundRobinRounds` (same circle method the
/// tournament round-robin uses); each round becomes one week (the `nil` side on
/// odd rosters = rest week, and no fixture is created for it). Results are
/// entered per match, and standings (W/L/points/sets) derive purely from the
/// completed `matches` list.
@Model
final class League {
    var name: String
    var dateCreated: Date

    @Relationship(deleteRule: .cascade, inverse: \LeagueMatch.league)
    var matches: [LeagueMatch]

    @Relationship(deleteRule: .nullify, inverse: \Player.leagues)
    var roster: [Player]

    var isCompleted: Bool {
        !matches.isEmpty && matches.allSatisfy { $0.isCompleted }
    }

    var completedMatches: [LeagueMatch] {
        matches.filter { $0.isCompleted }
    }

    /// Highest week number in the schedule (1-based); 0 while empty.
    var weeks: Int {
        matches.map(\.week).max() ?? 0
    }

    /// Sorted leaderboard, computed live from completed matches only. Ties
    /// break on wins, then points, then set differential, then name.
    struct StandingsRow: Identifiable {
        let player: Player
        var wins = 0
        var losses = 0
        var points = 0
        var setsWon = 0
        var setsLost = 0
        var matchesPlayed: Int { wins + losses }
        var setDifferential: Int { setsWon - setsLost }

        var id: PersistentIdentifier { player.id }
    }

    var standings: [StandingsRow] {
        var map: [PersistentIdentifier: StandingsRow] = [:]
        for entry in roster {
            map[entry.id] = StandingsRow(player: entry)
        }
        for match in matches where match.isCompleted {
            guard let winner = match.winner else { continue }
            let loser = (winner == match.playerOne) ? match.playerTwo : match.playerOne
            if var row = map[winner.id] {
                row.wins += 1
                row.points += 3
                row.setsWon += match.winnerSetsWon
                row.setsLost += match.winnerSetsLost
                map[winner.id] = row
            }
            if let loser, var row = map[loser.id] {
                row.losses += 1
                row.setsWon += match.loserSetsWon
                row.setsLost += match.loserSetsLost
                map[loser.id] = row
            }
        }
        return map.values.sorted { a, b in
            if a.wins != b.wins { return a.wins > b.wins }
            if a.points != b.points { return a.points > b.points }
            if a.setDifferential != b.setDifferential { return a.setDifferential > b.setDifferential }
            return a.player.name.localizedCaseInsensitiveCompare(b.player.name) == .orderedAscending
        }
    }

    /// Current leader (top of the live table). `nil` while nothing is played.
    var leader: Player? {
        standings.first?.player
    }

    init(name: String, roster: [Player], dateCreated: Date = .now) {
        self.name = name
        self.dateCreated = dateCreated
        self.matches = []
        self.roster = roster
    }
}

// MARK: - One scheduled / completed league fixture

/// A single fixture in the weekly schedule: crosses two roster members in one
/// numbered week. `winner` + `setScores` are written on completion using the
/// same score-line conventions as `TournamentMatch` ("4-6, 6-4, 6-1"), so the
/// standings math and future exports parse identically.
@Model
final class LeagueMatch {
    var week: Int
    var position: Int
    var playerOne: Player?
    var playerTwo: Player?
    var winner: Player?
    var setScores: String
    var statusRaw: String

    var league: League?

    var status: LeagueMatchStatus {
        LeagueMatchStatus(rawValue: statusRaw) ?? .pending
    }

    var isCompleted: Bool { status == .completed }

    var winnerSetsWon: Int { setsWonBy(true) }
    var loserSetsWon: Int { setsWonBy(false) }
    var winnerSetsLost: Int { loserSetsWon }
    var loserSetsLost: Int { winnerSetsWon }

    private func setsWonBy(_ winnerSide: Bool) -> Int {
        guard isCompleted else { return 0 }
        let parts = setScores.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !parts.isEmpty else {
            return winnerSide ? 3 : 2
        }
        var winnerSets = 0
        var loserSets = 0
        for part in parts {
            let scores = part.split(separator: "-")
            guard scores.count == 2, let a = Int(scores[0]), let b = Int(scores[1]) else { continue }
            if a > b { winnerSets += 1 } else { loserSets += 1 }
        }
        return winnerSide ? winnerSets : loserSets
    }

    var displayLabel: String {
        [playerOne?.name, playerTwo?.name].compactMap { $0 }.joined(separator: " vs ")
    }

    init(week: Int, position: Int, playerOne: Player?, playerTwo: Player?) {
        self.week = week
        self.position = position
        self.playerOne = playerOne
        self.playerTwo = playerTwo
        self.winner = nil
        self.setScores = ""
        self.statusRaw = LeagueMatchStatus.pending.rawValue
    }
}

// MARK: - League Export (PDF pipeline)

/// Plain Sendable snapshot of a league's live standings, taken on the MainActor.
/// Rendering (PDF) and tests consume this — never the model directly.
struct LeagueExportSnapshot: Sendable {
    struct Row: Sendable {
        let rank: Int
        let name: String
        let wins: Int
        let losses: Int
        let points: Int
        let setsWon: Int
        let setsLost: Int
    }

    let leagueName: String
    let dateLine: String
    let playerCount: Int
    let weeks: Int
    let rows: [Row]

    init(league: League) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        leagueName = league.name
        dateLine = formatter.string(from: league.dateCreated)
        playerCount = league.roster.count
        weeks = league.weeks
        rows = league.standings.enumerated().map { index, row in
            Row(
                rank: index + 1,
                name: row.player.name,
                wins: row.wins,
                losses: row.losses,
                points: row.points,
                setsWon: row.setsWon,
                setsLost: row.setsLost
            )
        }
    }
}