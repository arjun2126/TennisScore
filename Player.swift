import Foundation
import SwiftData

@Model
final class Player {
    var name: String
    var dateCreated: Date
    
    /// True for the device owner's profile ("Me"). Enforced single per store.
    /// Additive with a default — existing rows migrate with `false`.
    var isCurrentUser: Bool = false
    
    @Relationship(deleteRule: .nullify, inverse: \Match.playerOne) var matchesAsP1: [Match] = []
    @Relationship(deleteRule: .nullify, inverse: \Match.playerTwo) var matchesAsP2: [Match] = []

    /// Tournaments this player is entered in. `Tournament.entries` declares the
    /// `@Relationship` inverse. NOTE: this must NOT live inside a `#if` block —
    /// properties hidden by any conditional-compilation guard are silently
    /// omitted from the `@Model` macro's schema metadata in the current
    /// toolchain, which then fatals resolving the inverse at launch. The watch
    /// compiles it successfully against its own minimal `Tournament` mirror
    /// (`TournamentWatchModels.swift`), and never registers tournaments in its
    /// model container.
    @Relationship(deleteRule: .nullify) var inTournaments: [Tournament] = []

    /// Season leagues this player is a member of. `League.roster` declares the
    /// `@Relationship` inverse. Kept outside any `#if` guard for the same
    /// schema-metadata reason documented above `inTournaments`.
    @Relationship(deleteRule: .nullify) var leagues: [League] = []

    init(name: String) {
        self.name = name
        self.dateCreated = .now
    }
    
    var allMatches: [Match] {
        (matchesAsP1 + matchesAsP2).uniqued()
    }
    
    var matchCount: Int {
        allMatches.count
    }
    
    // MARK: - Primary User invariant (exactly one "Me" per store)
    
    static func currentUser(in context: ModelContext) -> Player? {
        let descriptor = FetchDescriptor<Player>(predicate: #Predicate { $0.isCurrentUser })
        return (try? context.fetch(descriptor))?.first
    }
    
    /// Marks `player` as Me and unmarks everyone else. Never deletes anything.
    static func setAsCurrentUser(_ player: Player, in context: ModelContext) {
        let descriptor = FetchDescriptor<Player>()
        if let all = try? context.fetch(descriptor) {
            for other in all where other !== player {
                other.isCurrentUser = false
            }
        }
        player.isCurrentUser = true
        try? context.save()
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}