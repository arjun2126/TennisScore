import SwiftUI
import SwiftData
import WatchKit

/// Standalone Watch match screen.
///
/// Binding fix for the "0-0" bug: the parent holds match *ownership* in
/// `@State var standaloneMatch: Match?`, but observation does not propagate
/// through Optional unwrapping — so this view takes the unwrapped model as
/// `@Bindable`, which wires SwiftUI observation directly to the Match.
/// Belt-and-braces: `.onChange(of: match.p1Points/p2Points)` bumps
/// `pointTick` (forcing a re-render of the pinned score) on every point.
struct StandaloneMatchView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var match: Match

    /// Refresh token: mutated on every point change to force re-render.
    @State private var pointTick = 0
    @State private var showingSideSwitch = false
    /// Debounce: blocks double-taps for 0.5s after each tap (with dimming).
    @State private var pointButtonsLocked = false
    @State private var showingSyncError = false
    @State private var syncErrorMessage = ""

    var body: some View {
        // Control Hub owns its layout (zero-scroll 3-zone); this view owns
        // the @Bindable model + tick that keep it live.
WatchControlHub(
            snap: ScoreSnapshot(local: match),
            isPaused: match.isPaused,
            canUndo: !match.undoStack.isEmpty,
            onPoint: { recordLocalPoint(player: $0) },
            onUndo: { undoLocalPoint() },
            onPauseToggle: { toggleLocalPause() },
            pointLocked: pointButtonsLocked
        )
        .onChange(of: match.p1Points) {
            // Targeted refresh: with @Bindable above, SwiftUI diffs only the
            // changed score labels (no wholesale view recreation).
            pointTick += 1
        }
        .onChange(of: match.p2Points) {
            pointTick += 1
        }
        .alert("Switch Sides", isPresented: $showingSideSwitch) {
            Button("Done") {
                match.recordSideSwitch()
                try? modelContext.save()
                showingSideSwitch = false
            }
        } message: {
            Text("Change ends for the next game")
        }
        .alert("Sync Failed", isPresented: $showingSyncError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(syncErrorMessage)
        }
    }

    private func toggleLocalPause() {
        WKInterfaceDevice.current().play(.click)
        withAnimation(Animation.springMedium) {
            if match.isPaused {
                match.resumeMatch()
            } else {
                match.pauseMatch()
            }
        }
        try? modelContext.save()
        WatchBridge.shared.sendOrQueue(["action": "watchPause", "matchID": match.matchID])
    }

    // MARK: - Local engine + sync

    private func watchMatchConfig() -> MatchConfiguration {
        var config = MatchConfiguration()
        config.setLength = match.setLength
        config.tieBreakLength = match.tieBreakLength
        config.bestOf = match.format.contains("5") ? 5 : 3
        config.advantageScoring = true
        return config
    }

    private func recordLocalPoint(player: Int) {
        // Debounce: one tap per 0.5s (buttons dim while locked).
        guard !pointButtonsLocked else { return }
        pointButtonsLocked = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pointButtonsLocked = false
        }
        WKInterfaceDevice.current().play(.click)
        let event = PointEvent(
            player: player == 1 ? match.playerOne : match.playerTwo,
            outcome: .winner,
            note: ""
        )
        // Optimistic UI: mutate the @Bindable model FIRST so the score
        // renders instantly, then fire the sync, then persist.
        match.pointEvents.append(event)
        let snapshot = match.createSnapshot()
        let changes = TennisEngine.processPoint(
            for: player,
            match: match,
            config: watchMatchConfig(),
            firstServer: match.firstServer
        )
        if changes.gameWon != nil {
            match.pushUndoAction(UndoAction(type: .game, player: changes.gameWon, previousState: snapshot, timestamp: Date()))
        } else {
            match.pushUndoAction(UndoAction(type: .point, player: player, previousState: snapshot, timestamp: Date()))
        }
        if changes.tieBreakStarted {
            match.pushUndoAction(UndoAction(type: .tieBreakStart, player: nil, previousState: snapshot, timestamp: Date()))
        }
        if changes.setWon != nil || changes.tieBreakWonBy != nil {
            match.pushUndoAction(UndoAction(type: .set, player: changes.setWon ?? changes.tieBreakWonBy, previousState: snapshot, timestamp: Date()))
        }
        if changes.matchWon {
            WKInterfaceDevice.current().play(.success)
            // Match over: close the tennis workout, snapshot biometrics.
            match.avgHeartRate = WatchWorkoutManager.shared.averageHeartRate
            match.totalCalories = WatchWorkoutManager.shared.activeCalories
            WatchWorkoutManager.shared.endWorkout()
        }
        let pointPayload: [String: Any] = [
            "action": "watchPoint",
            "matchID": match.matchID,
            "player": player,
            "avgHeartRate": WatchWorkoutManager.shared.averageHeartRate,
            "totalCalories": WatchWorkoutManager.shared.activeCalories
        ]
        WatchBridge.shared.sendScoring(pointPayload) { _ in
            // Transport failed: roll the optimistic point back and say so.
            DispatchQueue.main.async {
                match.restoreSnapshot(snapshot)
                _ = match.popUndoAction()
                try? modelContext.save()
                syncErrorMessage = "The iPhone didn't receive that point, so it was rolled back. Try again."
                showingSyncError = true
            }
        }
        // Persist on the NEXT runloop turn (still MainActor): the score render
        // commits first, so the disk write can never add perceived lag.
        // (SwiftData contexts are main-bound — background saves would corrupt.)
        DispatchQueue.main.async {
            try? modelContext.save()
        }
        if match.shouldPromptSideSwitch && !match.isPaused {
            showingSideSwitch = true
        }
    }

    private func undoLocalPoint() {
        WKInterfaceDevice.current().play(.click)
        guard let action = match.popUndoAction() else { return }
        withAnimation(Animation.springMedium) {
            match.restoreSnapshot(action.previousState)
        }
        try? modelContext.save()
        WatchBridge.shared.sendOrQueue(["action": "watchUndo", "matchID": match.matchID])
    }
}

#Preview {
    StandaloneMatchView(
        match: {
            let p1 = Player(name: "Player 1")
            let p2 = Player(name: "Player 2")
            return Match(playerOne: p1, playerTwo: p2, format: "Best of 3 • Set to 6 • Tie-break to 7 • Advantage", setLength: 6, tieBreakLength: 7)
        }()
    )
}
