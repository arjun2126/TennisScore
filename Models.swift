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

// MARK: - Undo Action Types

enum UndoActionType: String, Codable {
    case point = "Point"
    case game = "Game"
    case set = "Set"
    case tieBreakStart = "TieBreakStart"
}

struct UndoAction: Codable {
    let type: UndoActionType
    let player: Int? // 1 or 2, nil for non-player actions
    let previousState: MatchSnapshot
    let timestamp: Date
    
    var description: String {
        switch type {
        case .point:
            return player == 1 ? "Point: Player 1" : "Point: Player 2"
        case .game:
            return player == 1 ? "Game Won: Player 1" : "Game Won: Player 2"
        case .set:
            return player == 1 ? "Set Won: Player 1" : "Set Won: Player 2"
        case .tieBreakStart:
            return "Tie-break Started"
        }
    }
}

struct MatchSnapshot: Codable {
    let p1Points: Int; let p2Points: Int
    let p1Games: Int; let p2Games: Int
    let p1Sets: Int; let p2Sets: Int
    let isTieBreak: Bool
    let tieBreakP1Points: Int; let tieBreakP2Points: Int
    let pointEventsCount: Int
}

// MARK: - Match Model

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
    var setLength: Int
    var tieBreakLength: Int
    
    var p1Points: Int; var p2Points: Int
    var p1Games: Int; var p2Games: Int
    var p1Sets: Int; var p2Sets: Int
    var isTieBreak: Bool
    var tieBreakP1Points: Int; var tieBreakP2Points: Int
    var completedSets: [String]
    @Relationship(deleteRule: .cascade) var pointEvents: [PointEvent]

    var firstServer: Int = 1
    
    // Stable cross-device identity for Watch <-> iPhone sync (both targets share this model)
    var matchID: String = UUID().uuidString
    
    // Per-match biometrics (populated by wrist-sensed matches; 0 = unsensed).
    // Additive with defaults — existing rows migrate untouched.
    var avgHeartRate: Double = 0
    var totalCalories: Double = 0
    
    // Tournament linkage (To-Do #2 — The Hook). Plain String tags only, and
    // **watch-safe**: `Tournament`/`TournamentMatch` types never cross the
    // phone ⇆ watch bridge, so a live `Match` carries the stable scheduled
    // fixture ID + event name that the bracket auto-advance hook resolves against
    // on completionainer. Empty defaults = free-play matches migrate untouched.
    var tournamentMatchID: String = ""
    var tournamentName: String = ""
    
    // QoL Features
    var matchStartDate: Date?
    var pausedDuration: TimeInterval = 0
    var lastPauseDate: Date?
    var isPaused: Bool = false
    var lastSideSwitchGame: Int = 0 // Track last game total when sides switched

    // Singles rating linkage (Phase 6, spec). Additive scalars with defaults —
    // watch-safe and migration-free. `isRated` marks a match that counted
    // toward Glicko-2; deltas are the per-player points applied that period.
    var isRated: Bool = false
    var ratingDeltaP1: Double = 0
    var ratingDeltaP2: Double = 0
    /// "junior" | "adult" band the match was rated in ("" = free play).
    var ageBandRaw: String = ""
    /// Source event share token when the match was played from a rated event.
    var eventID: String = ""
    
    // Undo Stack (stored as JSON)
    var undoStackData: Data = Data()
    
    var undoStack: [UndoAction] {
        get {
            (try? JSONDecoder().decode([UndoAction].self, from: undoStackData)) ?? []
        }
        set {
            undoStackData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
    
    // Computed: Elapsed match time
    var elapsedTime: TimeInterval {
        guard let start = matchStartDate else { return 0 }
        let end = isPaused ? (lastPauseDate ?? Date()) : Date()
        return end.timeIntervalSince(start) - pausedDuration
    }
    
    var formattedElapsedTime: String {
        let totalSeconds = Int(elapsedTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    init(playerOne: Player, playerTwo: Player, format: String, location: String = "", setLength: Int = 6, tieBreakLength: Int = 7, firstServer: Int = 1) {
        self.playerOne = playerOne; self.playerTwo = playerTwo; self.format = format; self.location = location
        self.setLength = setLength; self.tieBreakLength = tieBreakLength; self.firstServer = firstServer
        self.winnerName = ""; self.setScores = ""; self.date = .now; self.isCompleted = false
        self.matchID = UUID().uuidString
        self.p1Points = 0; self.p2Points = 0; self.p1Games = 0; self.p2Games = 0
        self.p1Sets = 0; self.p2Sets = 0; self.isTieBreak = false; self.tieBreakP1Points = 0
        self.tieBreakP2Points = 0; self.completedSets = []; self.pointEvents = []
        self.matchStartDate = Date()
    }
    
    // MARK: - Timer Controls
    
    func pauseMatch() {
        guard !isPaused else { return }
        isPaused = true
        lastPauseDate = Date()
    }
    
    func resumeMatch() {
        guard isPaused, let pauseDate = lastPauseDate else { return }
        pausedDuration += Date().timeIntervalSince(pauseDate)
        isPaused = false
        lastPauseDate = nil
    }
    
    // MARK: - Undo Stack Management
    
    func pushUndoAction(_ action: UndoAction) {
        var stack = undoStack
        stack.append(action)
        // Keep last 20 actions
        if stack.count > 20 { stack.removeFirst(stack.count - 20) }
        undoStack = stack
    }
    
    func popUndoAction() -> UndoAction? {
        var stack = undoStack
        guard !stack.isEmpty else { return nil }
        return stack.removeLast()
    }
    
    func clearUndoStack() {
        undoStack = []
    }
    
    func createSnapshot() -> MatchSnapshot {
        MatchSnapshot(
            p1Points: p1Points, p2Points: p2Points,
            p1Games: p1Games, p2Games: p2Games,
            p1Sets: p1Sets, p2Sets: p2Sets,
            isTieBreak: isTieBreak,
            tieBreakP1Points: tieBreakP1Points, tieBreakP2Points: tieBreakP2Points,
            pointEventsCount: pointEvents.count
        )
    }
    
    func restoreSnapshot(_ snapshot: MatchSnapshot) {
        p1Points = snapshot.p1Points; p2Points = snapshot.p2Points
        p1Games = snapshot.p1Games; p2Games = snapshot.p2Games
        p1Sets = snapshot.p1Sets; p2Sets = snapshot.p2Sets
        isTieBreak = snapshot.isTieBreak
        tieBreakP1Points = snapshot.tieBreakP1Points; tieBreakP2Points = snapshot.tieBreakP2Points
        
        // Trim point events to match snapshot count
        while pointEvents.count > snapshot.pointEventsCount {
            pointEvents.removeLast()
        }
    }
    
    // MARK: - Side Switch Logic
    
    var shouldPromptSideSwitch: Bool {
        let totalGames = p1Games + p2Games
        // Switch on odd games (1, 3, 5...) but not at 0
        // In tie-break, switch every 6 points
        if isTieBreak {
            let totalPoints = tieBreakP1Points + tieBreakP2Points
            return totalPoints > 0 && totalPoints % 6 == 0 && totalPoints != lastSideSwitchGame
        }
        return totalGames > 0 && totalGames % 2 == 1 && totalGames != lastSideSwitchGame
    }
    
    func recordSideSwitch() {
        let totalGames = p1Games + p2Games
        if isTieBreak {
            lastSideSwitchGame = tieBreakP1Points + tieBreakP2Points
        } else {
            lastSideSwitchGame = totalGames
        }
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

// MARK: - Match Export (PDF pipeline; single source of truth)

/// Plain Sendable snapshot taken from the live Match on the MainActor.
/// Rendering (PDF) and tests consume this — never the model directly.
struct MatchExportSnapshot: Sendable {
    struct StatRow: Sendable {
        let name: String
        let aces: Int
        let winners: Int
        let unforcedErrors: Int
        let forcedErrors: Int
    }
    struct Note: Sendable {
        let player: String
        let text: String
    }
    
    let id: String
    let playerOne: String
    let playerTwo: String
    let winnerName: String
    let setScores: String
    let setsLine: String
    let format: String
    let location: String
    let dateLine: String
    let p1: StatRow
    let p2: StatRow
    let notes: [Note]
    
    init(_ match: Match) {
        func count(_ outcome: PointOutcome, _ player: Player) -> Int {
            match.pointEvents.filter { $0.player == player && $0.outcome == outcome }.count
        }
        func winners(_ player: Player) -> Int {
            count(.winner, player) + count(.serveWinner, player) + count(.returnWinner, player)
        }
        func row(_ player: Player) -> StatRow {
            StatRow(
                name: player.name,
                aces: count(.ace, player),
                winners: winners(player),
                unforcedErrors: count(.unforcedError, player),
                forcedErrors: count(.forcedError, player)
            )
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        id = match.matchID.isEmpty ? UUID().uuidString : match.matchID
        playerOne = match.playerOne.name
        playerTwo = match.playerTwo.name
        winnerName = match.winnerName
        setScores = match.setScores
        setsLine = "Sets \(match.p1Sets)-\(match.p2Sets)"
        format = match.format
        location = match.location.isEmpty ? "Not specified" : match.location
        dateLine = formatter.string(from: match.date)
        p1 = row(match.playerOne)
        p2 = row(match.playerTwo)
        notes = match.pointEvents.filter { !$0.note.isEmpty }.map {
            Note(player: $0.player.name, text: $0.note)
        }
    }
}

enum ExportError: Error {
    case emptyFile
}

/// Canonical export builder. Every section of the required data map is
/// emitted explicitly: header (date/location/winner), scoreboard (final
/// set score), per-player stats table, and point-by-point notes.
/// Pure functions of data read from SwiftData — never mutate the store.
struct ExportManager {
    static func matchSummary(_ match: Match) -> String {
        matchSummary(MatchExportSnapshot(match))
    }
    
    static func matchSummary(_ s: MatchExportSnapshot) -> String {
        func statRow(_ row: MatchExportSnapshot.StatRow) -> String {
            "\(row.name): Aces \(row.aces), Winners \(row.winners), Unforced Errors \(row.unforcedErrors), Forced Errors \(row.forcedErrors)"
        }
        var lines: [String] = []
        lines.append("TENNIS MATCH SUMMARY")
        lines.append("Date: \(s.dateLine)")
        lines.append("Location: \(s.location)")
        lines.append("Winner: \(s.winnerName.isEmpty ? "TBD" : s.winnerName)")
        lines.append("FINAL SCORE: \(s.setScores.isEmpty ? "—" : s.setScores) (\(s.setsLine))")
        lines.append("STATISTICS")
        lines.append(statRow(s.p1))
        lines.append(statRow(s.p2))
        lines.append("NOTES")
        if s.notes.isEmpty {
            lines.append("No notes recorded")
        } else {
            lines.append(contentsOf: s.notes.map { "• \($0.player): \($0.text)" })
        }
        lines.append("Shared from Vantage")
        return lines.joined(separator: "\n")
    }
    
    /// Writes data atomically to a temp PDF and verifies size > 0 bytes.
    /// Throws `.emptyFile` otherwise — the share sheet never opens on failure.
    /// Nonisolated/pure: safe to run inside `Task.detached`.
    nonisolated static func writeVerifiedPDF(data: Data, id: String) throws -> URL {
        guard !data.isEmpty else { throw ExportError.emptyFile }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Vantage-\(id).pdf")
        try data.write(to: url, options: .atomic)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size > 0 else {
            try? FileManager.default.removeItem(at: url)
            throw ExportError.emptyFile
        }
        return url
    }
}

/// Backwards-compatible entry point (single source: ExportManager).
func matchExportText(_ match: Match) -> String {
    ExportManager.matchSummary(match)
}