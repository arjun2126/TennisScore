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

    #if os(iOS)
    /// Tournaments this player is entered in. `Tournament` lives only in the
    /// iOS app target, so this inverse is gated out of the Watch build (which
    /// still compiles this file).
    @Relationship(deleteRule: .nullify) var inTournaments: [Tournament] = []
    #endif

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