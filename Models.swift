import Foundation
import SwiftData
import SwiftUI

enum PointOutcome: String, CaseIterable, Codable, Identifiable {
    case ace = "Ace", winner = "Winner", serveWinner = "Serve Winner", returnWinner = "Return Winner"
    case forcedError = "Forced Error", unforcedError = "Unforced Error", doubleFault = "Double Fault", other = "Other"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .ace: return "bolt.fill"
        case .winner: return "flame.fill"
        case .serveWinner: return "arrow.up.right"
        case .returnWinner: return "arrow.down.left"
        case .forcedError: return "arrow.turn.down.left"
        case .unforcedError: return "exclamationmark.triangle.fill"
        case .doubleFault: return "xmark.octagon.fill"
        case .other: return "circle.dashed"
        }
    }
    var color: Color {
        switch self {
        case .ace, .winner: return .yellow
        case .forcedError, .unforcedError, .doubleFault: return .red
        default: return .blue
        }
    }
}

@Model
final class PointEvent {
    var player: Player
    var outcomeRawValue: String
    var note: String
    var date: Date
    init(player: Player, outcome: PointOutcome, note: String = "", date: Date = .now) {
        self.player = player; self.outcomeRawValue = outcome.rawValue; self.note = note; self.date = date
    }
    var outcome: PointOutcome { PointOutcome(rawValue: outcomeRawValue) ?? .other }
}

@Model
final class Match {
    var playerOne: Player
    var playerTwo: Player
    var winnerName: String
    var setScores: String
    var format: String
    var location: String
    var date: Date
    var isCompleted: Bool
    
    // Dynamic Rules stored per match
    var setLength: Int // e.g., 6
    var tieBreakLength: Int // e.g., 7
    
    var p1Points: Int; var p2Points: Int
    var p1Games: Int; var p2Games: Int
    var p1Sets: Int; var p2Sets: Int
    var isTieBreak: Bool
    var tieBreakP1Points: Int; var tieBreakP2Points: Int
    var completedSets: [String]
    @Relationship(deleteRule: .cascade) var pointEvents: [PointEvent]

    init(playerOne: Player, playerTwo: Player, format: String, location: String = "", setLength: Int = 6, tieBreakLength: Int = 7) {
        self.playerOne = playerOne; self.playerTwo = playerTwo; self.format = format; self.location = location
        self.setLength = setLength; self.tieBreakLength = tieBreakLength
        self.winnerName = ""; self.setScores = ""; self.date = .now; self.isCompleted = false
        self.p1Points = 0; self.p2Points = 0; self.p1Games = 0; self.p2Games = 0
        self.p1Sets = 0; self.p2Sets = 0; self.isTieBreak = false; self.tieBreakP1Points = 0
        self.tieBreakP2Points = 0; self.completedSets = []; self.pointEvents = []
    }
}

struct MatchConfiguration {
    var bestOf: Int = 3
    var advantageScoring = true
    var setTieBreak = true
    var setLength: Int = 6
    var tieBreakLength: Int = 7
    var location = ""
    
    var setsToWin: Int { bestOf == 5 ? 3 : 2 }
    var formatText: String {
        "Best of \(bestOf) • Set to \(setLength) • Tie-break to \(tieBreakLength) • \(advantageScoring ? "Advantage" : "No-Ad")"
    }
}
