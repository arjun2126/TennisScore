import SwiftUI

/// Shared score snapshot so the Control Hub renders identically for
/// remote (MatchState) and standalone (@Bindable Match) sources.
struct ScoreSnapshot {
    var p1Name: String
    var p2Name: String
    var p1Points: String
    var p2Points: String
    var pointScore: String
    var p1Sets: Int
    var p2Sets: Int
    var p1Games: Int
    var p2Games: Int
    var gameScore: String
    var status: String
    var isTieBreak: Bool
    var tb1: Int
    var tb2: Int
    var p1Serving: Bool
    var p2Serving: Bool
    var isPaused: Bool
    var elapsed: String

    init(remote state: MatchState) {
        p1Name = state.playerOne
        p2Name = state.playerTwo
        // MatchState carries the combined string; split for the per-player P boxes.
        let parts = state.pointScore.components(separatedBy: " - ")
        p1Points = parts.first ?? state.p1Score
        p2Points = parts.count > 1 ? parts[1] : state.p2Score
        pointScore = state.pointScore
        p1Sets = state.p1Sets
        p2Sets = state.p2Sets
        p1Games = state.p1Games
        p2Games = state.p2Games
        gameScore = state.gameScore
        status = state.status
        isTieBreak = state.isTieBreak
        tb1 = state.tieBreakP1Points
        tb2 = state.tieBreakP2Points
        p1Serving = state.p1Serving
        p2Serving = state.p2Serving
        isPaused = state.isPaused
        elapsed = state.formattedElapsedTime
    }

    init(local match: Match) {
        var config = MatchConfiguration()
        config.setLength = match.setLength
        config.tieBreakLength = match.tieBreakLength
        config.bestOf = match.format.contains("5") ? 5 : 3
        config.advantageScoring = true
        let currentSet = match.p1Sets + match.p2Sets + 1
        let statusText: String
        if match.isCompleted {
            statusText = "Match Finished"
        } else if match.isTieBreak {
            statusText = "Set \(currentSet): Tie-break to \(config.tieBreakLength)"
        } else {
            statusText = "Set \(currentSet) • First to \(config.setLength) games"
        }
        p1Name = match.playerOne.name
        p2Name = match.playerTwo.name
        p1Points = TennisEngine.calculateScore(points: match.p1Points, opponentPoints: match.p2Points, isTieBreak: match.isTieBreak, tieBreakPoints: match.tieBreakP1Points, advantageScoring: true)
        p2Points = TennisEngine.calculateScore(points: match.p2Points, opponentPoints: match.p1Points, isTieBreak: match.isTieBreak, tieBreakPoints: match.tieBreakP2Points, advantageScoring: true)
        pointScore = "\(p1Points) - \(p2Points)"
        p1Sets = match.p1Sets
        p2Sets = match.p2Sets
        p1Games = match.p1Games
        p2Games = match.p2Games
        gameScore = "\(match.p1Games)-\(match.p2Games)"
        status = statusText
        isTieBreak = match.isTieBreak
        tb1 = match.tieBreakP1Points
        tb2 = match.tieBreakP2Points
        p1Serving = TennisEngine.currentServer(
            p1Games: match.p1Games, p2Games: match.p2Games,
            isTieBreak: match.isTieBreak,
            tieBreakP1Points: match.tieBreakP1Points, tieBreakP2Points: match.tieBreakP2Points,
            firstServer: match.firstServer
        ) == 1
        p2Serving = TennisEngine.currentServer(
            p1Games: match.p1Games, p2Games: match.p2Games,
            isTieBreak: match.isTieBreak,
            tieBreakP1Points: match.tieBreakP1Points, tieBreakP2Points: match.tieBreakP2Points,
            firstServer: match.firstServer
        ) == 2
        isPaused = match.isPaused
        elapsed = match.formattedElapsedTime
    }
}

/// Zero-scroll Control Hub. Three fixed zones, no ScrollView:
/// Zone 1 (top): S-G-P Score Card, fixed 60pt.
/// Zone 2 (middle): Quick Point buttons — the largest elements, flex-filled.
/// Zone 3 (bottom): compact Undo + Pause row.
struct WatchControlHub: View {
    let snap: ScoreSnapshot
    let isPaused: Bool
    let canUndo: Bool
    let onPoint: (Int) -> Void
    let onUndo: () -> Void
    let onPauseToggle: () -> Void
    /// Debounce flag: true for 0.5s after a tap (visual tap feedback +
    /// double-input guard). Owned by the parent, which runs the timer.
    let pointLocked: Bool

    @ObservedObject private var workout = WatchWorkoutManager.shared

    var body: some View {
        // Single screen: fixed card + flex buttons + control + tiny footer.
        // No ScrollView, no overlays — everything fits without scrolling.
        VStack(spacing: 4) {
            // Top: fixed compact S-G-P Score Card.
            scoreCard
                .frame(height: 56)

            // Middle: large Add Point buttons (flex-filled, the largest).
            HStack(spacing: 6) {
                quickPointButton(name: watchDisplayName(snap.p1Name), color: Color.mintAccent, serving: snap.p1Serving, player: 1)
                quickPointButton(name: watchDisplayName(snap.p2Name), color: Color.orangeAccent, serving: snap.p2Serving, player: 2)
            }

            // Footer: tiny biometric row (below the buttons).
            if workout.isRunning {
                healthFooter
            }

            // Bottom: small Undo + Pause buttons.
            HStack(spacing: 6) {
                Button(action: { onUndo() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(Color.white.opacity(0.15))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(!canUndo)
                .accessibilityLabel("Undo last point")

                Button(action: { onPauseToggle() }) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(isPaused ? Color.success : Color.warning)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPaused ? "Resume match" : "Pause match")
            }
            .padding(.vertical, 4)
            .font(.caption2)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.courtDark)
    }

    /// Tiny footer biometric row (single line, subtle).
    private var healthFooter: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.red)
                Text("\(Int(workout.heartRate)) BPM")
                    .font(.caption2)
                    .foregroundStyle(Color.gray500)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            HStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.orangeAccent)
                Text("\(Int(workout.activeCalories)) kcal")
                    .font(.caption2)
                    .foregroundStyle(Color.gray500)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Heart rate \(Int(workout.heartRate)) beats per minute. Active calories \(Int(workout.activeCalories)) kilocalories.")
    }

    private func quickPointButton(name: String, color: Color, serving: Bool, player: Int) -> some View {
        Button(action: { onPoint(player) }) {
            VStack(spacing: 2) {
                if serving {
                    Image(systemName: "tennisball.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                }
                Text(name)
                    .font(.footnote)
                    .bold()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .frame(maxHeight: .infinity)
            .background(color)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
.buttonStyle(.plain)
                .disabled(isPaused || pointLocked)
                .opacity(pointLocked ? 0.6 : 1.0)
                .accessibilityLabel("Add point for \(name)")
    }

    // MARK: - Zone 1: fixed-grid S-G-P card (HStack of three VStacks)

    private var scoreCard: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                    .frame(maxWidth: .infinity)
                Text("S")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.gray500)
                    .minimumScaleFactor(0.5)
                    .frame(width: 26)
                Text("G")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.gray500)
                    .minimumScaleFactor(0.5)
                    .frame(width: 26)
                Text("P")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .frame(width: 34)
            }
            .frame(height: 14)
            scoreRow(name: watchDisplayName(snap.p1Name), color: Color.mintAccent, s: "\(snap.p1Sets)", g: "\(snap.p1Games)", p: snap.p1Points, serving: snap.p1Serving)
            scoreRow(name: watchDisplayName(snap.p2Name), color: Color.orangeAccent, s: "\(snap.p2Sets)", g: "\(snap.p2Games)", p: snap.p2Points, serving: snap.p2Serving)
        }
        .padding(.horizontal, 4)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Score. \(snap.p1Name): \(snap.p1Sets) sets, \(snap.p1Games) games, \(snap.p1Points). \(snap.p2Name): \(snap.p2Sets) sets, \(snap.p2Games) games, \(snap.p2Points).")
    }

    private func scoreRow(name: String, color: Color, s: String, g: String, p: String, serving: Bool) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                // Fixed-frame ball slot, always reserved (hidden when not
                // serving) so the icon can never be squeezed out by the name.
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 16, height: 16)
                    .foregroundStyle(color)
                    .opacity(serving ? 1 : 0)
                    .accessibilityLabel(serving ? "Serving" : "")
                Text(name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(s)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 26)
            Text(g)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 26)
            Text(p)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .frame(width: 34)
        }
        .frame(maxHeight: .infinity)
    }
}

extension MatchState {
    var setScoreDetail: String {
        "Sets: \(p1Sets)-\(p2Sets)"
    }

    var formattedElapsedTime: String {
        let totalSeconds = Int(elapsedTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
