import Foundation
import SwiftData

@Model
final class Player {
    var name: String
    var dateCreated: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Match.playerOne) var matchesAsP1: [Match] = []
    @Relationship(deleteRule: .cascade, inverse: \Match.playerTwo) var matchesAsP2: [Match] = []

    init(name: String) {
        self.name = name
        self.dateCreated = .now
    }
}
