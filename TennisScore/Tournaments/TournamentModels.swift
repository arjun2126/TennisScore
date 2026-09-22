import Foundation
import SwiftData

// MARK: - Tournament Types

enum TournamentType: String, CaseIterable, Codable, Identifiable, Sendable {
    case knockout
    case roundRobin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .knockout: "Knockout"
        case .roundRobin: "Round Robin"
        }
    }

    var systemImage: String {
        switch self {
        case .knockout: "figure.tennis"
        case .roundRobin: "tablecells.fill"
        }
    }
}

enum TournamentMatchStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: "Upcoming"
        case .inProgress: "Live"
        case .completed: "Complete"
        }
    }
}

/// A reusable schedule of `Player` entries played to a single set length and
/// tie-break length. Two supported formats:
///  - `.knockout`: a single-elimination bracket with optional seeding and byes.
///  - `.roundRobin`: the circle method — every player meets every other.
@Model
final class Tournament {
    var name: String
    var typeRaw: String
    var setLength: Int
    var tieBreakLength: Int
    var seeded: Bool
    var dateCreated: Date
    var isCompleted: Bool

    /// The full match list. Knockout stores every round shell (byes included);
    /// round-robin stores one `TournamentMatch` per scheduled pair. Cascades so
    /// deleting the tournament also removes its matches.
    @Relationship(deleteRule: .cascade, inverse: \TournamentMatch.tournament)
    var matches: [TournamentMatch]

    /// All entrants. `Player` is the shared SwiftData model, so an existing
    /// Rival Profile can be entered into any number of tournaments and the
    /// reverse relationship lights up on the Player screen.
    @Relationship(deleteRule: .nullify, inverse: \Player.inTournaments)
    var entries: [Player]

    var type: TournamentType {
        TournamentType(rawValue: typeRaw) ?? .knockout
    }

    /// Bracket leaf count for the current entry count (smallest power of two).
    var bracketSize: Int {
        DrawEngine.bracketSize(for: entries.count)
    }

    /// Number of knockout rounds implied by the bracket size.
    var depth: Int {
        DrawEngine.depth(for: bracketSize)
    }

    var completedMatches: [TournamentMatch] {
        matches.filter { $0.status == .completed }
    }

    var isFullyCompleted: Bool {
        matches.count > 0 && matches.allSatisfy { $0.isCompleted }
    }

    /// Final-round match that has a winner → the tournament champion.
    var champion: Player? {
        guard type == .knockout else { return nil }
        let finalRound = matches.filter { $0.round == depth }
        return finalRound.first { $0.status == .completed }?.winner
    }

    /// Round-robin standings, computed live from the completed matches:
    /// wins, losses, and set-differential used for ordering.
    struct StandingsRow {
        let player: Player
        var wins = 0
        var losses = 0
        var setsWon = 0
        var setsLost = 0
        var matchesPlayed: Int { wins + losses }
        var setDifferential: Int { setsWon - setsLost }
    }

    var roundRobinStandings: [StandingsRow] {
        guard type == .roundRobin else { return [] }
        var map: [String: StandingsRow] = [:]
        for entry in entries {
            map[entry.name] = StandingsRow(player: entry)
        }
        for tm in matches where tm.status == .completed {
            guard let winner = tm.winner else { continue }
            let loser = (winner == tm.playerOne) ? tm.playerTwo : tm.playerOne
            if var winnerRow = map[winner.name] {
                winnerRow.wins += 1
                winnerRow.setsWon += tm.winnerSetsWon
                winnerRow.setsLost += tm.winnerSetsLost
                map[winner.name] = winnerRow
            }
            if let loser, var loserRow = map[loser.name] {
                loserRow.losses += 1
                loserRow.setsWon += tm.loserSetsWon
                loserRow.setsLost += tm.loserSetsLost
                map[loser.name] = loserRow
            }
        }
        return map.values.sorted { a, b in
            if a.wins != b.wins { return a.wins > b.wins }
            if a.setDifferential != b.setDifferential { return a.setDifferential > b.setDifferential }
            return a.player.name.localizedCaseInsensitiveCompare(b.player.name) == .orderedAscending
        }
    }

    init(
        name: String,
        type: TournamentType,
        setLength: Int = 6,
        tieBreakLength: Int = 7,
        seeded: Bool = false,
        entries: [Player],
        dateCreated: Date = .now
    ) {
        self.name = name
        self.typeRaw = type.rawValue
        self.setLength = setLength
        self.tieBreakLength = tieBreakLength
        self.seeded = seeded
        self.dateCreated = dateCreated
        self.isCompleted = false
        self.matches = []
        self.entries = entries
    }
}

/// One scheduled (or completed) fixture inside a `Tournament`. Knockout rounds
/// hang off `round`/`position` so the bracket can be laid out from pure math;
/// round-robin fixtures map 1:1 to a single `position` per scheduled pair.
@Model
final class TournamentMatch {
    var round: Int
    var position: Int
    var playerOne: Player?
    var playerTwo: Player?
    var winner: Player?
    var scoreLine: String
    var statusRaw: String
    var courtNumber: String
    var startTime: Date?

    /// Stable cross-device identity: this is copied onto `Match.tournamentMatchID`
    /// so the phone ↔ watch bridge can report which tournament fixture a live
    /// match belongs to without referencing Tournament types (watch-safe).
    var matchID: String

    var tournament: Tournament?

    var status: TournamentMatchStatus {
        TournamentMatchStatus(rawValue: statusRaw) ?? .pending
    }

    var isCompleted: Bool { status == .completed }

    /// A first-round shell where one slot is nil — the lone entrant is awarded
    /// advancement on creation and no match is ever launched here.
    var isBye: Bool {
        round == 1 && (playerOne == nil || playerTwo == nil)
    }

    /// True when both players are known and the fixture still needs to be played.
    var isPlayable: Bool {
        !isBye && status == .pending && playerOne != nil && playerTwo != nil
    }

    /// Sets won by the winner vs the loser, parsed from `scoreLine`
    /// ("4-6, 6-3, 6-1"-style) or defaulting to best-of-3 math.
    var winnerSetsWon: Int { setsWonBy(true) }
    var loserSetsWon: Int { setsWonBy(false) }
    var winnerSetsLost: Int { loserSetsWon }
    var loserSetsLost: Int { winnerSetsWon }

    private func setsWonBy(_ winnerSide: Bool) -> Int {
        guard isCompleted else { return 0 }
        let parts = scoreLine.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !parts.isEmpty else {
            // No score line → infer sets from best-of-3: winner 3-2
            return winnerSide ? 3 : 2
        }
        var winnerSets = 0
        var loserSets = 0
        for part in parts {
            let scores = part.split(separator: "-")
            guard scores.count == 2,
                  let a = Int(scores[0]), let b = Int(scores[1]) else { continue }
            if a > b { winnerSets += 1 } else { loserSets += 1 }
        }
        return winnerSide ? winnerSets : loserSets
    }

    var displayLabel: String {
        isBye
            ? (playerOne?.name ?? playerTwo?.name ?? "Bye")
            : [playerOne?.name, playerTwo?.name].compactMap { $0 }.joined(separator: " vs ")
    }

    var detailLine: String {
        if isCompleted, let winner {
            return "\(winner.name) wins \(scoreLine)"
        }
        if isBye {
            return "Bye — advances automatically"
        }
        if status == .inProgress {
            return "In progress"
        }
        return "Upcoming"
    }

    init(
        round: Int,
        position: Int,
        playerOne: Player? = nil,
        playerTwo: Player? = nil,
        courtNumber: String = "",
        startTime: Date? = nil
    ) {
        self.round = round
        self.position = position
        self.playerOne = playerOne
        self.playerTwo = playerTwo
        self.courtNumber = courtNumber
        self.startTime = startTime
        self.winner = nil
        self.scoreLine = ""
        self.statusRaw = TournamentMatchStatus.pending.rawValue
        self.matchID = UUID().uuidString
    }
}
