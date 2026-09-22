import Foundation
import SwiftData

// MARK: - The Hook

/// App-side orchestrator for a `Tournament`. Turns an entered player list into
/// its complete fixture schedule (knockout shell + real first round, or the
/// round-robin circle), launches a scheduled fixture into the live scorer as a
/// real `Match`, and — the heart of this step — **auto-advances the bracket the
/// instant a fixture completes**, walking any successive byes all the way to a
/// real pairing (or the champion).
@MainActor
final class TournamentManager {
    static let shared = TournamentManager()
    private init() {}

    /// Post by the setup UI when a scheduled fixture has been promoted to a
    /// live `Match`; the home scorer observes it to present the launched match.
    static let launchMatchNotification = Notification.Name("TournamentLaunchMatch")

    /// Key used by the live `Match` tag that connects a scored match to its
    /// scheduled fixture across the phone ⇆ watch bridge (plain strings only —
    /// watch-safe).
    static let launchMatchIDKey = "launchMatchID"

    // MARK: - Creation / scheduling

    /// Builds the full fixture schedule for `entries`. Knockout writes **every**
    /// round shell (round 1 real, deeper rounds empty), byes already expressed
    /// as nil slots; round-robin writes one match per scheduled pair. Byes are
    /// auto-resolved at creation so a short field converges on a champion.
    @discardableResult
    func createTournament(
        name: String,
        type: TournamentType,
        setLength: Int = 6,
        tieBreakLength: Int = 7,
        seeded: Bool = false,
        entries: [Player],
        in context: ModelContext
    ) -> Tournament {
        let tournament = Tournament(
            name: name,
            type: type,
            setLength: setLength,
            tieBreakLength: tieBreakLength,
            seeded: seeded,
            entries: entries,
            dateCreated: .now
        )
        context.insert(tournament)

        switch type {
        case .knockout:
            writeKnockoutShells(for: tournament, in: context)
        case .roundRobin:
            writeRoundRobinFixtures(for: tournament, in: context)
        }
        try? context.save()
        return tournament
    }

    private func writeKnockoutShells(for tournament: Tournament, in context: ModelContext) {
        let size = DrawEngine.bracketSize(for: tournament.entries.count)
        let depth = DrawEngine.depth(for: size)
        let pairs: [(Player?, Player?)] = tournament.seeded
            ? DrawEngine.seededPairs(entries: tournament.entries, size: size)
            : DrawEngine.shuffledPairs(entries: tournament.entries, size: size)

        // Round 1: real pairings from the (seeded/shuffled) draw; byes arrive as
        // nil slots here. Broken shells still carry a `position` for layout.
        for fixtureIndex in 0..<size / 2 {
            let fixture = TournamentMatch(
                round: 1,
                position: fixtureIndex,
                playerOne: pairs[fixtureIndex].0,
                playerTwo: pairs[fixtureIndex].1
            )
            fixture.tournament = tournament
            context.insert(fixture)
        }

        // Rounds 2…depth: empty shells (nil slots). Winners drop in as they emerge.
        if depth > 1 {
            for round in 2...depth {
                let fixturesInRound = size >> round
                for position in 0..<fixturesInRound {
                    let fixture = TournamentMatch(round: round, position: position)
                    fixture.tournament = tournament
                    context.insert(fixture)
                }
            }
        }

        // Auto-resolve round-1 byes: a lone player walks over into round 2 now.
        // Repeatedly hoisting the walkover handles a bracket with layered byes.
        for `round` in 1..<depth {
            for fixture in tournament.matches where fixture.round == `round` && fixture.position < (size >> `round`) {
                applyByeWalkovers(from: fixture, tournament: tournament)
            }
        }
    }

    private func writeRoundRobinFixtures(for tournament: Tournament, in context: ModelContext) {
        let rounds = DrawEngine.roundRobinRounds(count: tournament.entries.count)
        var position = 0
        for roundPairs in rounds {
            for pair in roundPairs {
                guard let partner = pair.1 else { continue } // odd field: bye = rest, no fixture
                let fixture = TournamentMatch(
                    round: 1,
                    position: position,
                    playerOne: tournament.entries[pair.0],
                    playerTwo: tournament.entries[partner]
                )
                fixture.tournament = tournament
                context.insert(fixture)
                position += 1
            }
        }
    }

    /// Resolves the fixture's bye if only one player is present: award the
    /// walkover, then hoist that player into the next round. If the landing
    /// shell in turn has no opponent, keep walking (chained byes).
    private func applyByeWalkovers(from fixture: TournamentMatch, tournament: Tournament) {
        guard fixture.playerTwo == nil || fixture.playerOne == nil,
              let only = fixture.playerOne ?? fixture.playerTwo,
              fixture.status == .pending else { return }

        fixture.winner = only
        fixture.statusRaw = TournamentMatchStatus.completed.rawValue
        fixture.scoreLine = ""

        let nextRound = fixture.round + 1
        let nextPosition = fixture.position / 2
        guard let next = tournament.matches.first(where: { $0.round == nextRound && $0.position == nextPosition }) else {
            tournament.isCompleted = true
            return
        }

        // Winner fills the correct half of the next shell (even fixture →
        // left slot, odd → right slot).
        if fixture.position % 2 == 0 { next.playerTwo = only } else { next.playerOne = only }
        applyByeWalkovers(from: next, tournament: tournament)
    }

    // MARK: - Launching a live fixture

    /// Promotes a scheduled fixture into a real, live-scored `Match` tagged with
    /// the fixture's stable identity + tournament name (watch-safe strings), then
    /// posts the launch notification so the home scorer can present it.
    @discardableResult
    func launchMatch(_ fixture: TournamentMatch, in context: ModelContext) -> Match? {
        guard let p1 = fixture.playerOne, let p2 = fixture.playerTwo else { return nil }
        let match = Match(
            playerOne: p1,
            playerTwo: p2,
            format: "Tournament",
            location: fixture.tournament?.name ?? ""
        )
        match.tournamentMatchID = fixture.matchID
        match.tournamentName = fixture.tournament?.name ?? ""
        context.insert(match)
        fixture.statusRaw = TournamentMatchStatus.inProgress.rawValue
        try? context.save()

        NotificationCenter.default.post(
            name: Self.launchMatchNotification,
            object: nil,
            userInfo: [Self.launchMatchIDKey: fixture.matchID]
        )
        return match
    }

    // MARK: - The Hook: bracket advancement on completion

    /// Called by the live scorer the instant a `Match` completes. Records the
    /// result onto its scheduled fixture (winner, score line, status) and — for
    /// knockout — auto-advances the winner into the next round, walking any
    /// chained byes. Round-robin standings are computed live from results.
    func handleMatchCompletion(_ match: Match, in context: ModelContext) {
        guard match.isCompleted else { return }
        guard let fixture = tournamentFixture(id: match.tournamentMatchID, in: context) else { return }
        guard let tournament = fixture.tournament else { return }

        fixture.playerOne = match.playerOne
        fixture.playerTwo = match.playerTwo
        fixture.scoreLine = match.setScores
        fixture.statusRaw = TournamentMatchStatus.completed.rawValue
        fixture.winner = match.winnerName == match.playerOne.name ? match.playerOne : match.playerTwo

        if tournament.type == .knockout, let winner = fixture.winner {
            advance(winner: winner, from: fixture, in: tournament)
        }
        if let champion = tournament.champion {
            tournament.isCompleted = true
        }
        try? context.save()
    }

    /// Live-score hook (To-Do #2.5): mirrors an in-progress `Match` onto its
    /// bracket fixture every time `setScores` changes, so the bracket shows the
    /// scoreLine live without waiting for completion. The winner is only
    /// resolved by `handleMatchCompletion(_:in:)` — an in-progress fixture never
    /// claims a bracket winner prematurely.
    func handleMatchUpdate(_ match: Match, in context: ModelContext) {
        guard let fixture = tournamentFixture(id: match.tournamentMatchID, in: context) else { return }
        fixture.scoreLine = match.setScores
        if fixture.statusRaw != TournamentMatchStatus.completed.rawValue {
            fixture.statusRaw = TournamentMatchStatus.inProgress.rawValue
        }
        try? context.save()
    }

    private func advance(winner: Player, from fixture: TournamentMatch, in tournament: Tournament) {
        let nextRound = fixture.round + 1
        let nextPosition = fixture.position / 2

        guard nextRound <= tournament.depth,
              let next = tournament.matches.first(where: { $0.round == nextRound && $0.position == nextPosition }) else {
            // No shell above → this was the final; the champion is decided.
            tournament.isCompleted = true
            return
        }

        // Winner occupies the correct side slot of the next shell (even fixture
        // feeds the left half, odd the right half).
        if fixture.position % 2 == 0 {
            next.playerOne = winner
        } else {
            next.playerTwo = winner
        }

        // If the landing shell only has one player (a bye above), keep walking.
        applyByeWalkovers(from: next, tournament: tournament)
    }

    private func tournamentFixture(id: String, in context: ModelContext) -> TournamentMatch? {
        let tournaments = (try? context.fetch(FetchDescriptor<Tournament>())) ?? []
        for tournament in tournaments {
            if let fixture = tournament.matches.first(where: { $0.matchID == id }) {
                return fixture
            }
        }
        return nil
    }
}
