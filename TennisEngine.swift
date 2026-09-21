import Foundation

struct TennisEngine {
    
    // MARK: - Score Display
    
    static func calculateScore(
        points: Int,
        opponentPoints: Int,
        isTieBreak: Bool,
        tieBreakPoints: Int,
        advantageScoring: Bool = true
    ) -> String {
        if isTieBreak { return "\(tieBreakPoints)" }
        
        if points >= 3 && opponentPoints >= 3 {
            if points == opponentPoints { return "40" }
            if points == opponentPoints + 1 { return "Ad" }
            if points >= opponentPoints + 2 { return "Game" }
        }
        
        if !advantageScoring && points >= 4 && points > opponentPoints {
            return "Game"
        }
        
        switch points {
        case 0: return "Love"
        case 1: return "15"
        case 2: return "30"
        default: return "40"
        }
    }
    
    // MARK: - Match Status
    
    static func getStatus(match: Match, config: MatchConfiguration) -> String {
        if match.isCompleted { return "Match Finished" }
        let currentSet = match.p1Sets + match.p2Sets + 1
        if match.isTieBreak { return "Set \(currentSet): Tie-break to \(config.tieBreakLength)" }
        return "Set \(currentSet) • First to \(config.setLength) games"
    }
    
    // MARK: - Serving Logic
    
    /// Determines which player is serving based on games played in current set
    /// Returns 1 for playerOne, 2 for playerTwo
    static func currentServer(
        p1Games: Int,
        p2Games: Int,
        isTieBreak: Bool,
        tieBreakP1Points: Int,
        tieBreakP2Points: Int,
        firstServer: Int = 1
    ) -> Int {
        if isTieBreak {
            let totalPoints = tieBreakP1Points + tieBreakP2Points
            // ITF Rule 62: firstServer serves point 1; opponent serves points 2-3;
            // thereafter the serve alternates every two points.
            if totalPoints == 0 { return firstServer }
            let group = (totalPoints - 1) / 2
            if group % 2 == 0 {
                return (firstServer == 1) ? 2 : 1
            } else {
                return firstServer
            }
        }
        
        let totalGames = p1Games + p2Games
        // Standard game serving: alternate every game
        return (firstServer == 1) ? (totalGames % 2 == 0 ? 1 : 2) : (totalGames % 2 == 0 ? 2 : 1)
    }
    
    // MARK: - Game/Set/Match Logic
    
    /// Checks if a game is won under current rules
    static func isGameWon(
        playerPoints: Int,
        opponentPoints: Int,
        advantageScoring: Bool
    ) -> Bool {
        if advantageScoring {
            return playerPoints >= 4 && playerPoints >= opponentPoints + 2
        } else {
            // No-Ad: first to 4 points wins (at 3-3, next point wins)
            return playerPoints >= 4 && playerPoints > opponentPoints
        }
    }
    
    /// Checks if a tie-break is won (win by 2, minimum tieBreakLength)
    static func isTieBreakWon(
        playerPoints: Int,
        opponentPoints: Int,
        tieBreakLength: Int
    ) -> Bool {
        return playerPoints >= tieBreakLength && playerPoints >= opponentPoints + 2
    }
    
    /// Checks if a set is won
    static func isSetWon(
        playerGames: Int,
        opponentGames: Int,
        setLength: Int,
        setTieBreakEnabled: Bool,
        isTieBreak: Bool
    ) -> Bool {
        if isTieBreak { return false } // Tie-break handled separately
        
        // Standard set: win by 2, minimum setLength
        if playerGames >= setLength && playerGames >= opponentGames + 2 {
            return true
        }
        
        // Tie-break at setLength-all (e.g., 6-6)
        if setTieBreakEnabled && playerGames == setLength && opponentGames == setLength {
            return false // Will trigger tie-break
        }
        
        return false
    }
    
    /// Checks if match is won
    static func isMatchWon(playerSets: Int, setsToWin: Int) -> Bool {
        return playerSets >= setsToWin
    }
    
    // MARK: - Complete State Calculation
    
    /// Processes a point scored and returns all state changes
    static func processPoint(
        for player: Int,
        match: Match,
        config: MatchConfiguration,
        firstServer: Int
    ) -> MatchStateChanges {
        var changes = MatchStateChanges()
        
        if match.isTieBreak {
            changes = processTieBreakPoint(for: player, match: match, config: config, firstServer: firstServer)
        } else {
            changes = processStandardPoint(for: player, match: match, config: config, firstServer: firstServer)
        }
        
        // Check for set completion after game win
        if changes.gameWon != nil {
            changes = checkSetCompletion(match: match, config: config, changes: changes)
        }
        
        // Check for match completion
        if changes.setWon != nil {
            changes = checkMatchCompletion(match: match, config: config, changes: changes)
        }
        
        return changes
    }
    
    private static func processStandardPoint(
        for player: Int,
        match: Match,
        config: MatchConfiguration,
        firstServer: Int
    ) -> MatchStateChanges {
        var changes = MatchStateChanges()
        
        if player == 1 {
            match.p1Points += 1
        } else {
            match.p2Points += 1
        }
        
        let p1Points = match.p1Points
        let p2Points = match.p2Points
        
        if isGameWon(playerPoints: p1Points, opponentPoints: p2Points, advantageScoring: config.advantageScoring) {
            match.p1Games += 1
            match.p1Points = 0
            match.p2Points = 0
            changes.gameWon = 1
        } else if isGameWon(playerPoints: p2Points, opponentPoints: p1Points, advantageScoring: config.advantageScoring) {
            match.p2Games += 1
            match.p1Points = 0
            match.p2Points = 0
            changes.gameWon = 2
        }
        
        return changes
    }
    
    private static func processTieBreakPoint(
        for player: Int,
        match: Match,
        config: MatchConfiguration,
        firstServer: Int
    ) -> MatchStateChanges {
        var changes = MatchStateChanges()
        
        if player == 1 {
            match.tieBreakP1Points += 1
        } else {
            match.tieBreakP2Points += 1
        }
        
        if isTieBreakWon(playerPoints: match.tieBreakP1Points, opponentPoints: match.tieBreakP2Points, tieBreakLength: config.tieBreakLength) {
            changes.setWon = 1
            changes.tieBreakWonBy = 1
        } else if isTieBreakWon(playerPoints: match.tieBreakP2Points, opponentPoints: match.tieBreakP1Points, tieBreakLength: config.tieBreakLength) {
            changes.setWon = 2
            changes.tieBreakWonBy = 2
        }
        
        return changes
    }
    
    private static func checkSetCompletion(
        match: Match,
        config: MatchConfiguration,
        changes: MatchStateChanges
    ) -> MatchStateChanges {
        var updated = changes
        
        // Check if tie-break should start
        if config.setTieBreak && match.p1Games == config.setLength && match.p2Games == config.setLength {
            match.isTieBreak = true
            match.tieBreakP1Points = 0
            match.tieBreakP2Points = 0
            updated.tieBreakStarted = true
            return updated
        }
        
        // Check for standard set win
        if isSetWon(playerGames: match.p1Games, opponentGames: match.p2Games, setLength: config.setLength, setTieBreakEnabled: config.setTieBreak, isTieBreak: false) {
            updated.setWon = 1
        } else if isSetWon(playerGames: match.p2Games, opponentGames: match.p1Games, setLength: config.setLength, setTieBreakEnabled: config.setTieBreak, isTieBreak: false) {
            updated.setWon = 2
        }
        
        return updated
    }
    
    private static func checkMatchCompletion(
        match: Match,
        config: MatchConfiguration,
        changes: MatchStateChanges
    ) -> MatchStateChanges {
        var updated = changes
        let setWinner = changes.setWon ?? changes.tieBreakWonBy
        
        guard let winner = setWinner else { return updated }
        
        // Record completed set
        match.completedSets.append("\(match.p1Games)-\(match.p2Games)")
        
        if winner == 1 { match.p1Sets += 1 } else { match.p2Sets += 1 }
        
        // Reset for next set
        match.p1Games = 0
        match.p2Games = 0
        match.p1Points = 0
        match.p2Points = 0
        match.isTieBreak = false
        match.tieBreakP1Points = 0
        match.tieBreakP2Points = 0
        
        updated.setWon = winner
        
        if isMatchWon(playerSets: match.p1Sets, setsToWin: config.setsToWin) {
            match.isCompleted = true
            match.winnerName = match.playerOne.name
            match.setScores = match.completedSets.joined(separator: ", ")
            updated.matchWon = true
            updated.matchWinner = 1
        } else if isMatchWon(playerSets: match.p2Sets, setsToWin: config.setsToWin) {
            match.isCompleted = true
            match.winnerName = match.playerTwo.name
            match.setScores = match.completedSets.joined(separator: ", ")
            updated.matchWon = true
            updated.matchWinner = 2
        }
        
        return updated
    }
}

// MARK: - State Change Container

struct MatchStateChanges {
    var gameWon: Int? = nil           // 1 or 2
    var setWon: Int? = nil            // 1 or 2
    var tieBreakWonBy: Int? = nil     // 1 or 2
    var tieBreakStarted: Bool = false
    var matchWon: Bool = false
    var matchWinner: Int? = nil       // 1 or 2
}