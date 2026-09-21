import SwiftUI
import SwiftData
import WatchKit

struct WatchView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var bridge = WatchBridge.shared
    @State private var showingToss = false
    @State private var showingPlayerSelection = false
    /// Debounce for remote scoring (mirrors the standalone lock).
    @State private var remotePointLocked = false
    /// Connectivity guard: on a truly cold cache the wrist waits for the
    /// phone's full-state reply; after the timeout we fall through to the
    /// (still functional) setup page while sync keeps retrying behind it.
    @State private var connectingTimedOut = false

    /// Ownership only: the live standalone match is rendered through
    /// StandaloneMatchView (@Bindable) so point updates refresh the score.
    @State private var standaloneMatch: Match?

    private var state: MatchState { bridge.matchState }

    var body: some View {
        NavigationStack {
            Group {
                if let local = standaloneMatch {
                    if local.isCompleted {
                        WatchMatchResultsView(
                            match: local,
                            onNewMatch: {
                                standaloneMatch = nil
                                showingPlayerSelection = true
                            },
                            onDone: { standaloneMatch = nil }
                        )
                    } else {
                        // Control Hub: zero-scroll 3-zone layout (card + points + control).
                        StandaloneMatchView(match: local)
                    }
                } else if bridge.isConnecting && !connectingTimedOut {
                    connectingView
                } else if state.uiState == .active {
                    // Remote Control Hub: same zero-scroll layout, phone-driven.
                    WatchControlHub(
                        snap: ScoreSnapshot(remote: state),
                        isPaused: state.isPaused,
                        canUndo: state.undoStackCount > 0,
                        onPoint: { recordPoint(player: $0 == 1 ? "p1" : "p2") },
                        onUndo: { undoPoint() },
                        onPauseToggle: { WatchBridge.shared.send(["action": "pause"]) },
                        pointLocked: remotePointLocked
                    )
                } else {
                    VStack(spacing: 0) {
                        remoteSlimBar
                        ScrollView {
                            VStack(spacing: Spacing.sm) {
                                if state.uiState == .matchComplete {
                                    matchCompleteView
                                } else {
                                    setupView
                                }
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .background(Color.black)
            .sheet(isPresented: $showingToss, onDismiss: {
                // Snap back to the phone's truth whenever the toss closes.
                WatchBridge.shared.requestCurrentState()
            }) {
                TossView(onTossComplete: handleTossComplete)
            }
            .sheet(isPresented: $showingPlayerSelection) {
                PlayerSelectionView(onStart: { p1, p2, server in
                    showingPlayerSelection = false
                    startStandaloneMatch(p1Name: p1, p2Name: p2, firstServer: server)
                })
            }
            .alert("Switch Sides", isPresented: .constant(state.showSideSwitchPrompt)) {
                Button("Done") {
                    WatchBridge.shared.send(["action": "sideSwitchAcknowledged"])
                }
            } message: {
                Text("Change ends for the next game")
            }
        }
        .onChange(of: state.gameWon) { _, newValue in
            if newValue != nil {
                WKInterfaceDevice.current().play(.success)
            }
        }
        .onChange(of: state.matchWon) { _, newValue in
            if newValue {
                WKInterfaceDevice.current().play(.success)
            }
        }
        .onChange(of: state.hasActiveMatch) { _, hasMatch in
            // Mirrored workout: a phone-started match opens the wrist session,
            // and its completion/reset closes it. Standalone mode owns itself.
            guard standaloneMatch == nil else { return }
            if hasMatch {
                WatchWorkoutManager.shared.startTennisWorkout()
            } else {
                WatchWorkoutManager.shared.endWorkout()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchBridge.watchActionNotification)) { notification in
            // Cross-device lifecycle: iPhone Reset ends the wrist workout.
            guard let message = notification.userInfo as? [String: Any],
                  message["action"] as? String == "endWorkout" else { return }
            WatchWorkoutManager.shared.endWorkout()
        }
        .onAppear {
            WatchBridge.shared.requestCurrentState()
            WatchWorkoutManager.shared.requestAuthorization()
            connectingTimedOut = false
            // Safety valve: never leave a cold-cache wrist on a spinner.
            // The retrying full-state request continues in the background.
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                connectingTimedOut = true
            }
        }
    }

    // MARK: - Slim bar (setup / victory screens; scoring uses the Hub)

    private var remoteSlimBar: some View {
        Text("Vantage • Companion")
            .font(.caption)
            .foregroundStyle(Color.gray500)
            .padding(.vertical, 4)
    }

    // MARK: - Connectivity loading state

    /// Branded "Connecting…" placeholder shown only while the cache is cold and
    /// the phone's full-state reply hasn't landed (never mid-match).
    private var connectingView: some View {
        VStack(spacing: Spacing.sm) {
            ProgressView()
                .controlSize(.large)
                .padding(.bottom, Spacing.xs)
            Text("Connecting…")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Fetching match state from iPhone")
                .font(.caption)
                .foregroundStyle(Color.gray500)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Setup (first-class: start on the wrist, no redirect)

    private var setupView: some View {
        VStack(spacing: Spacing.sm) {
            Text("Start and score the match right here. It syncs to iPhone when connected.")
                .font(.caption)
                .foregroundStyle(Color.gray500)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            startOnWatchButton
            tossButton
        }
        .padding(.top, Spacing.sm)
    }

    private var startOnWatchButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            showingPlayerSelection = true
        } label: {
            Label("Start on Watch", systemImage: "play.fill")
                .font(.footnote)
                .bold()
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Color.mintAccent)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Remote views (iPhone-originated match; scoring via the Hub)

    private var matchCompleteView: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.warning)

            Text("MATCH COMPLETE")
                .font(.caption)
                .bold()
                .foregroundStyle(Color.gray500)

            let winner = state.matchWinner == 1 ? state.playerOne : state.playerTwo
            Text(watchDisplayName(winner))
                .font(.footnote)
                .bold()
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text("\(state.p1Sets) - \(state.p2Sets)")
                .font(Typography.scoreSmall)
                .bold()
                .foregroundStyle(Color.mintAccent)

            Text(state.setScoreDetail)
                .font(.caption)
                .foregroundStyle(Color.gray500)
                .lineLimit(1)

            Button {
                WKInterfaceDevice.current().play(.click)
                // Clear any stale remote result before starting fresh.
                WatchBridge.shared.resetMatchState()
                showingPlayerSelection = true
            } label: {
                Label("New Match", systemImage: "plus.circle.fill")
                    .font(.footnote)
                    .bold()
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color.mintAccent)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, Spacing.sm)
    }

    private var tossButton: some View {
        Button { showingToss = true } label: {
            Label("Toss for Serve", systemImage: "bitcoinsign.circle.fill")
                .font(.footnote)
                .bold()
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Color.yellow)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Standalone match ownership + sync

    private func fetchOrCreateWatchPlayer(name: String) -> Player {
        let descriptor = FetchDescriptor<Player>(predicate: #Predicate { $0.name == name })
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            return existing
        }
        let player = Player(name: name)
        modelContext.insert(player)
        return player
    }

    private func startStandaloneMatch(p1Name: String, p2Name: String, firstServer: Int) {
        let p1 = fetchOrCreateWatchPlayer(name: p1Name)
        let p2 = fetchOrCreateWatchPlayer(name: p2Name)
        let format = "Best of 3 • Set to 6 • Tie-break to 7 • Advantage"
        let match = Match(
            playerOne: p1,
            playerTwo: p2,
            format: format,
            location: "",
            setLength: 6,
            tieBreakLength: 7,
            firstServer: firstServer
        )
        modelContext.insert(match)
        try? modelContext.save()
        standaloneMatch = match
        // Clean slate: the phone's old remote state must not bleed through.
        WatchBridge.shared.resetMatchState()
        WKInterfaceDevice.current().play(.success)
        // HealthKit: a wrist-started match opens a tennis workout (queued-safe).
        WatchWorkoutManager.shared.startTennisWorkout()
        // Sync now if connected; otherwise the system queues it for reconnect.
        WatchBridge.shared.sendOrQueue([
            "action": "createMatch",
            "matchID": match.matchID,
            "playerOne": p1Name,
            "playerTwo": p2Name,
            "format": format,
            "location": "",
            "setLength": 6,
            "tieBreakLength": 7,
            "firstServer": firstServer
        ])
    }

    // MARK: - Companion actions (remote mode)

    /// Toss finished with no redirects: back to whichever match is live,
    /// or into player selection when nothing is live yet.
    private func handleTossComplete() {
        showingToss = false
        WKInterfaceDevice.current().play(.success)
        if standaloneMatch == nil && !bridge.matchState.hasActiveMatch {
            showingPlayerSelection = true
        } else {
            WatchBridge.shared.requestCurrentState()
        }
    }

    private func recordPoint(player: String) {
        // Debounce: one tap per 0.5s (the hub dims while locked).
        guard !remotePointLocked else { return }
        remotePointLocked = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            remotePointLocked = false
        }
        WKInterfaceDevice.current().play(.click)
        WatchBridge.shared.send(["action": "point", "player": player])
    }

    private func undoPoint() {
        WKInterfaceDevice.current().play(.click)
        WatchBridge.shared.send(["action": "undo"])
    }
}

#Preview {
    WatchView()
}
