import Foundation
import SwiftData

// MARK: - League Orchestrator

/// App-side orchestrator for a `League`. Persists a new season with its roster;
/// `generateSchedule` (Phase 3) fills the weekly fixtures using the same
/// circle-method math the round-robin tournament uses.
@MainActor
final class LeagueManager {
    static let shared = LeagueManager()
    private init() {}

    /// Creates a season and immediately fills its weekly fixture schedule
    /// (one full round-robin cycle).
    @discardableResult
    func createLeague(name: String, roster: [Player], in context: ModelContext) -> League {
        let league = League(name: name, roster: roster, dateCreated: .now)
        context.insert(league)
        generateSchedule(for: league, in: context)
        return league
    }

    /// Generates the full weekly schedule for `league` using the same
    /// circle-method round-robin math as tournaments (`DrawEngine`). Each round
    /// is one numbered week; the `nil` side on an odd roster rests (no fixture
    /// is created for it).
    func generateSchedule(for league: League, in context: ModelContext) {
        guard league.matches.isEmpty else { return }
        let rounds = DrawEngine.roundRobinRounds(count: league.roster.count)
        let roster = league.roster
        for (weekIndex, roundPairs) in rounds.enumerated() {
            for (position, pair) in roundPairs.enumerated() {
                guard let partner = pair.1 else { continue } // odd field: rest week
                let match = LeagueMatch(
                    week: weekIndex + 1,
                    position: position,
                    playerOne: roster[pair.0],
                    playerTwo: roster[partner]
                )
                match.league = league
                context.insert(match)
            }
        }
        try? context.save()
    }
}