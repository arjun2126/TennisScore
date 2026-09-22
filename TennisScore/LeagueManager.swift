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

    /// Creates an empty season: name + roster only. The weekly fixture schedule
    /// is generated separately so the two concerns stay independently testable.
    @discardableResult
    func createLeague(name: String, roster: [Player], in context: ModelContext) -> League {
        let league = League(name: name, roster: roster, dateCreated: .now)
        context.insert(league)
        try? context.save()
        return league
    }
}