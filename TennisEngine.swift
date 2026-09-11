import Foundation

struct TennisEngine {
    static func calculateScore(_ points: Int, opponentPoints: Int, isTieBreak: Bool, tieBreakPoints: Int) -> String {
        if isTieBreak { return "\(tieBreakPoints)" }
        if points >= 3 && opponentPoints >= 3 {
            if points == opponentPoints { return "40" }
            if points == opponentPoints + 1 { return "Ad" }
            if points >= opponentPoints + 2 { return "Game" }
        }
        switch points {
        case 0: return "Love"
        case 1: return "15"
        case 2: return "30"
        default: return "40"
        }
    }
    
    static func getStatus(match: Match, config: MatchConfiguration) -> String {
        if match.isCompleted { return "Match Finished" }
        let currentSet = match.p1Sets + match.p2Sets + 1
        if match.isTieBreak { return "Set \(currentSet): Tie-break" }
        return "Set \(currentSet) in progress"
    }
}
