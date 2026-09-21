import SwiftUI
import SwiftData
import Foundation

struct MatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Match> { $0.isCompleted == false }) private var activeMatches: [Match]
    @Query(sort: \Player.name) private var rosterPlayers: [Player]
    @StateObject private var bridge = WatchBridge.shared
    
    @State private var configuration = MatchConfiguration()
    @State private var selectedP1: Player?
    @State private var selectedP2: Player?
    @State private var location = ""
    @State private var showingSetup = false
    @State private var pendingPlayer: Player?
    
    @State private var matchForResults: Match?
    @State private var showingResults = false
    
    // QoL Features State
    @State private var showingUndoHistory = false
    @State private var showingSideSwitchAlert = false
    @State private var editingPlayerName: Player?
    @State private var editNameText = ""
    @State private var timer: Timer?
    
    var currentMatch: Match? { activeMatches.first }

    /// Monotonic state-frame counter: stamps every pushed frame so the Watch's
    /// sequence guard can drop out-of-order deliveries (never rewind a score).
    @State private var stateSeqCounter: Int = 0
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.courtDark.ignoresSafeArea()
            if let match = currentMatch {
                VStack(spacing: 0) {
                    mainScoreboard(match)
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // Pause/Resume Banner
                            if match.isPaused {
                                pauseBanner
                            }
                            
                            // Side Switch Alert
                            if showingSideSwitchAlert {
                                sideSwitchBanner
                            }
                            
                            sectionHeader("ADD POINT")
                            HStack(spacing: DesignSystem.Spacing.md) {
                                playerActionCard(player: match.playerOne, color: .mintAccent, isServing: isPlayerServing(match, player: 1))
                                playerActionCard(player: match.playerTwo, color: .orangeAccent, isServing: isPlayerServing(match, player: 2))
                            }
                            liveTicker(match)
                            
                            // Undo History Drawer
                            if showingUndoHistory, !match.undoStack.isEmpty {
                                undoHistoryDrawer(match)
                            }
                            
                            controlRow(match)
                                .padding(.bottom, DesignSystem.Spacing.xl)
                        }
                        .padding(.horizontal, DesignSystem.Layout.screenPadding)
                        .padding(.top, DesignSystem.Spacing.lg)
                    }
                }
                .onAppear {
                    startTimer(for: match)
                    checkSideSwitch(match: match)
                }
                .onDisappear {
                    timer?.invalidate()
                }
            } else {
                emptyStateUI
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WatchAction"))) { notification in
            guard let message = notification.userInfo as? [String: Any],
                  let action = message["action"] as? String else { return }
            handleWatchAction(action, message: message)
        }
        .onAppear {
            if let match = currentMatch {
                WatchBridge.shared.updateWatchState(data: watchStatePayload(match: match))
            }
            PhoneWorkoutManager.shared.requestAuthorization()
        }
        .sheet(isPresented: $showingSetup) { MatchSetupView(selectedP1: $selectedP1, selectedP2: $selectedP2, configuration: $configuration, location: $location, onStart: { p1, p2, server in startNewMatch(p1: p1, p2: p2, firstServer: server) }) }
        .sheet(item: $pendingPlayer) { player in
            PointEntryView(player: player) { outcome, note in recordPoint(player: player, outcome: outcome, note: note) }
        }
        .fullScreenCover(isPresented: $showingResults) {
            if let match = matchForResults {
                MatchResultsView(match: match, onStartNew: {
                    modelContext.delete(match)
                    matchForResults = nil
                    showingResults = false
                    selectedP1 = nil; selectedP2 = nil
                }, onDismiss: {
                    matchForResults = nil
                    showingResults = false
                })
            }
        }
        .alert("Edit Player Name", isPresented: .constant(editingPlayerName != nil), presenting: editingPlayerName) { player in
            TextField("Name", text: $editNameText)
            Button("Save") {
                player.name = editNameText
                try? modelContext.save()
                pushWatchUpdate()
                editingPlayerName = nil
                editNameText = ""
            }
            Button("Cancel", role: .cancel) { editingPlayerName = nil }
        } message: { _ in Text("Enter new name for player") }
    }
    
    // MARK: - Timer
    
    private func startTimer(for match: Match) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if match.isPaused { return }
        }
    }
    
    // MARK: - Watch Actions
    
    private func handleWatchAction(_ action: String, message: [String: Any]) {
        // Companion actions that must work even when there is NO active match
        // (e.g. fresh phone, watch requesting setup or a state sync).
        switch action {
        case "openSetup":
            // Match Lock: never open setup over a live match.
            guard currentMatch == nil else {
                print("🔒 Watch openSetup ignored: match already in progress")
                return
            }
            showingSetup = true
            print("🎮 Watch action received: \(action)")
            return
        case "requestState", "watchConnected":
            pushCurrentStateToWatch()
            print("🎮 Watch action received: \(action)")
            return
        case "createMatch":
            // First-class companion: the Watch created a match locally.
            // Mirror it into iPhone SwiftData (idempotent by matchID).
            createMirrorMatch(from: message)
            print("🎮 Watch action received: \(action)")
            return
        case "watchPoint":
            guard let id = message["matchID"] as? String,
                  let playerIndex = message["player"] as? Int,
                  let mirror = mirrorMatch(id: id),
                  !mirror.isCompleted else { return }
            // Carry the wrist biometrics onto the mirror (missing keys keep prior).
            if let hr = message["avgHeartRate"] as? Double { mirror.avgHeartRate = hr }
            if let kcal = message["totalCalories"] as? Double { mirror.totalCalories = kcal }
            recordPoint(
                player: playerIndex == 1 ? mirror.playerOne : mirror.playerTwo,
                outcome: .winner,
                note: ""
            )
            print("🎮 Watch action received: \(action)")
            return
        case "watchUndo":
            guard let id = message["matchID"] as? String,
                  let mirror = mirrorMatch(id: id) else { return }
            undoLastAction(match: mirror)
            print("🎮 Watch action received: \(action)")
            return
        case "watchPause":
            guard let id = message["matchID"] as? String,
                  let mirror = mirrorMatch(id: id) else { return }
            togglePause(match: mirror)
            print("🎮 Watch action received: \(action)")
            return
        default:
            break
        }
        guard let match = currentMatch else { return }
        switch action {
        case "point":
            guard let playerKey = message["player"] as? String else { return }
            let player = playerKey == "p2" ? match.playerTwo : match.playerOne
            recordPoint(player: player, outcome: .winner, note: "")
        case "undo":
            undoLastAction(match: match)
        case "pause":
            togglePause(match: match)
        case "sideSwitchAcknowledged":
            match.recordSideSwitch()
            showingSideSwitchAlert = false
            pushWatchUpdate()
        default:
            break
        }
        print("🎮 Watch action received: \(action)")
    }
    
    // MARK: - Watch-Originated Mirror (first-class companion sync)
    
    private func mirrorMatch(id: String) -> Match? {
        guard !id.isEmpty else { return nil }
        let descriptor = FetchDescriptor<Match>(predicate: #Predicate { $0.matchID == id })
        return (try? modelContext.fetch(descriptor))?.first
    }
    
    private func fetchOrCreatePlayer(name: String) -> Player {
        let descriptor = FetchDescriptor<Player>(predicate: #Predicate { $0.name == name })
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            return existing
        }
        let player = Player(name: name)
        modelContext.insert(player)
        return player
    }
    
    private func createMirrorMatch(from message: [String: Any]) {
        guard let id = message["matchID"] as? String, !id.isEmpty,
              let p1Name = message["playerOne"] as? String, !p1Name.isEmpty,
              let p2Name = message["playerTwo"] as? String, !p2Name.isEmpty else { return }
        // Idempotent: replayed offline queue entries must not duplicate.
        if mirrorMatch(id: id) != nil {
            pushWatchUpdate()
            return
        }
        let p1 = fetchOrCreatePlayer(name: p1Name)
        let p2 = fetchOrCreatePlayer(name: p2Name)
        let mirror = Match(
            playerOne: p1,
            playerTwo: p2,
            format: message["format"] as? String ?? "Best of 3 • Set to 6 • Tie-break to 7 • Advantage",
            location: message["location"] as? String ?? "",
            setLength: message["setLength"] as? Int ?? 6,
            tieBreakLength: message["tieBreakLength"] as? Int ?? 7,
            firstServer: message["firstServer"] as? Int ?? 1
        )
        mirror.matchID = id
        modelContext.insert(mirror)
        try? modelContext.save()
        pushWatchUpdate()
    }
    
    // MARK: - Pause/Resume
    
    private func togglePause(match: Match) {
        withAnimation(DesignSystem.Animation.springMedium) {
            if match.isPaused {
                match.resumeMatch()
                HapticManager.notification(.success)
            } else {
                match.pauseMatch()
                HapticManager.impact(.heavy)
            }
        }
        pushWatchUpdate()
    }
    
    private var pauseBanner: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.warning)
                .accessibilityHidden(true)
            Text("MATCH PAUSED")
                .font(DesignSystem.Typography.captionLarge)
                .bold()
                .tracking(2)
                .foregroundStyle(DesignSystem.Colors.warning)
            Spacer()
            Button("Resume") { togglePause(match: currentMatch!) }
                .font(DesignSystem.Typography.labelMedium)
                .fontWeight(.semibold)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.mintAccent)
                .foregroundStyle(.black)
                .clipShape(Capsule())
                .accessibilityLabel("Resume match")
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Match paused. Tap resume to continue.")
    }
    
    // MARK: - Side Switch
    
    private func checkSideSwitch(match: Match) {
        if match.shouldPromptSideSwitch && !match.isPaused && !showingSideSwitchAlert {
            withAnimation(DesignSystem.Animation.springMedium) {
                showingSideSwitchAlert = true
            }
            #if os(iOS)
            HapticManager.notification(.warning)
            #endif
            
            // Also send to Watch
            WatchBridge.shared.send(["action": "sideSwitchPrompt"])
        }
    }
    
    private var sideSwitchBanner: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.info)
                .accessibilityHidden(true)
            Text("SWITCH SIDES")
                .font(DesignSystem.Typography.captionLarge)
                .bold()
                .tracking(2)
                .foregroundStyle(DesignSystem.Colors.info)
            Spacer()
            Button("Done") {
                currentMatch?.recordSideSwitch()
                withAnimation(DesignSystem.Animation.springMedium) {
                    showingSideSwitchAlert = false
                }
                pushWatchUpdate()
            }
            .font(DesignSystem.Typography.labelMedium)
            .fontWeight(.semibold)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(DesignSystem.Colors.info)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .accessibilityLabel("Acknowledge side switch")
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.info.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Switch sides for the next game. Tap done when complete.")
    }
    
    // MARK: - Undo History
    
    private func undoLastAction(match: Match) {
        guard let action = match.popUndoAction() else { return }
        withAnimation(DesignSystem.Animation.springMedium) {
            match.restoreSnapshot(action.previousState)
        }
        HapticManager.impact(.medium)
        pushWatchUpdate()
    }
    
    private func undoToAction(match: Match, action: UndoAction) {
        var stack = match.undoStack
        guard let index = stack.firstIndex(where: { $0.timestamp == action.timestamp }) else { return }
        let actionsToRemove = stack[(index + 1)...]
        for _ in actionsToRemove { _ = stack.popLast() }
        withAnimation(DesignSystem.Animation.springMedium) {
            match.undoStack = stack
            match.restoreSnapshot(action.previousState)
        }
        HapticManager.notification(.success)
        withAnimation(DesignSystem.Animation.springMedium) {
            showingUndoHistory = false
        }
        pushWatchUpdate()
    }
    
    private func undoHistoryDrawer(_ match: Match) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("UNDO HISTORY")
                    .font(DesignSystem.Typography.captionLarge)
                    .bold()
                    .tracking(2)
                    .foregroundStyle(DesignSystem.Colors.gray500)
                Spacer()
                Button { withAnimation(DesignSystem.Animation.springMedium) { showingUndoHistory = false } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.headlineSmall)
                        .foregroundStyle(DesignSystem.Colors.gray500)
                }
            }
            
            ForEach(match.undoStack.reversed(), id: \.timestamp) { action in
                Button {
                    undoToAction(match: currentMatch!, action: action)
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: actionIcon(action.type))
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundStyle(actionColor(action.type))
                            .frame(width: 24)
                        Text(action.description)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(action.timestamp, format: .dateTime.hour().minute().second())
                            .font(DesignSystem.Typography.captionSmall)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.glassBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.courtMid)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.glassBorder, lineWidth: 0.5)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func actionIcon(_ type: UndoActionType) -> String {
        switch type {
        case .point: return "circle.fill"
        case .game: return "trophy.fill"
        case .set: return "flag.fill"
        case .tieBreakStart: return "timer"
        }
    }
    
    private func actionColor(_ type: UndoActionType) -> Color {
        switch type {
        case .point: return DesignSystem.Colors.info
        case .game: return DesignSystem.Colors.success
        case .set: return DesignSystem.Colors.warning
        case .tieBreakStart: return .purple
        }
    }
    
    // MARK: - Control Row
    
    private func controlRow(_ match: Match) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Pause/Resume Button
            Button { togglePause(match: match) } label: {
                Image(systemName: match.isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(DesignSystem.Typography.displaySmall)
                    .foregroundStyle(match.isPaused ? DesignSystem.Colors.success : DesignSystem.Colors.warning)
            }
            .buttonStyle(PlainIconButtonStyle(size: 56, background: .clear, foreground: match.isPaused ? DesignSystem.Colors.success : DesignSystem.Colors.warning))
            .accessibilityLabel(match.isPaused ? "Resume Match" : "Pause Match")
            
            Spacer()
            
            // Undo History Button
            Button { withAnimation(DesignSystem.Animation.springMedium) { showingUndoHistory.toggle() } } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(DesignSystem.Typography.headlineLarge)
                    .foregroundStyle(match.undoStack.isEmpty ? DesignSystem.Colors.gray300 : DesignSystem.Colors.white)
            }
            .buttonStyle(PlainIconButtonStyle(size: 56, background: .clear))
            .disabled(match.undoStack.isEmpty)
            .accessibilityLabel("Undo History")
            
            // Reset Button
            Button(role: .destructive) {
                modelContext.delete(match)
                // Clean exit: no lingering lock-screen widget for a reset match.
                ActivityManager.shared.stopActivity()
                // A reset abandons the match: close the iPhone workout too.
                PhoneWorkoutManager.shared.endWorkout()
                stateSeqCounter += 1
                WatchBridge.shared.updateWatchState(data: ["event": "stateUpdate", "ts": Date().timeIntervalSince1970, "seq": stateSeqCounter, "hasActiveMatch": false])
                // A reset abandons the match: close any wrist workout (queued if offline).
                WatchBridge.shared.sendOrQueue(["action": "endWorkout"])
            } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(DesignSystem.Typography.headlineLarge)
                    .foregroundStyle(DesignSystem.Colors.error.opacity(0.7))
            }
            .buttonStyle(PlainIconButtonStyle(size: 56, background: .clear))
            .accessibilityLabel("Reset Match")
        }
    }
    
    // MARK: - Helpers
    
    private func isPlayerServing(_ match: Match, player: Int) -> Bool {
        return TennisEngine.currentServer(
            p1Games: match.p1Games,
            p2Games: match.p2Games,
            isTieBreak: match.isTieBreak,
            tieBreakP1Points: match.tieBreakP1Points,
            tieBreakP2Points: match.tieBreakP2Points,
            firstServer: match.firstServer
        ) == player
    }
    
    private func matchConfig(_ match: Match) -> MatchConfiguration {
        var config = MatchConfiguration()
        config.setLength = match.setLength
        config.tieBreakLength = match.tieBreakLength
        config.bestOf = match.format.contains("5") ? 5 : 3
        config.advantageScoring = true
        return config
    }
    
    private func matchStatusText(_ match: Match) -> String {
        let config = matchConfig(match)
        if match.isCompleted { return "Match Finished" }
        let currentSet = match.p1Sets + match.p2Sets + 1
        if match.isTieBreak { return "Set \(currentSet): Tie-break to \(config.tieBreakLength)" }
        return "Set \(currentSet) • First to \(config.setLength) games"
    }
    
    private func pointDisplay(_ points: Int, opponentPoints: Int, isTieBreak: Bool, tieBreakPoints: Int, advantageScoring: Bool) -> String {
        TennisEngine.calculateScore(
            points: points,
            opponentPoints: opponentPoints,
            isTieBreak: isTieBreak,
            tieBreakPoints: tieBreakPoints,
            advantageScoring: advantageScoring
        )
    }
    
    // MARK: - Main Scoreboard
    
    private func mainScoreboard(_ match: Match) -> some View {
        VStack(spacing: 0) {
            // Header with Timer and Status
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxs) {
                    Text("LIVE MATCH")
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .tracking(2)
                        .foregroundStyle(DesignSystem.Colors.mintAccent)
                    Text(matchStatusText(match))
                        .font(DesignSystem.Typography.headlineSmall)
                        .foregroundStyle(.white)
                }
                Spacer()
                
                // Match Timer
                Text(match.formattedElapsedTime)
                    .font(DesignSystem.Typography.monoMedium)
                    .foregroundStyle(match.isPaused ? DesignSystem.Colors.warning : DesignSystem.Colors.white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.courtMid)
                    .clipShape(Capsule())
                    .onTapGesture { togglePause(match: match) }
                    .accessibilityLabel("Match time: \(match.formattedElapsedTime). Tap to \(match.isPaused ? "resume" : "pause")")
                
                Button { showingSetup = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(DesignSystem.Typography.labelLarge)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(DesignSystem.Colors.glassBackground)
                        .clipShape(Circle())
                }
                .disabled(currentMatch != nil)
                .opacity(currentMatch != nil ? 0.4 : 1.0)
                .accessibilityLabel(currentMatch != nil ? "Match Setup (locked during live match)" : "Match Settings")
                .accessibilityHint(currentMatch != nil ? "Reset or complete the match to change setup" : "Open match setup")
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.courtMid)
            
            // Player Names with Edit on Long Press
            HStack(alignment: .bottom, spacing: DesignSystem.Spacing.md) {
                playerNameView(match.playerOne, color: .mintAccent, isServing: isPlayerServing(match, player: 1)) { editingPlayerName = match.playerOne; editNameText = match.playerOne.name }
                Text("VS")
                    .font(DesignSystem.Typography.captionSmall)
                    .bold()
                    .foregroundStyle(DesignSystem.Colors.gray500)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                playerNameView(match.playerTwo, color: .orangeAccent, isServing: isPlayerServing(match, player: 2)) { editingPlayerName = match.playerTwo; editNameText = match.playerTwo.name }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)
            
            // Score Boxes
            HStack(spacing: DesignSystem.Spacing.md) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ScoreBox(value: "\(match.p1Sets)", label: "S", color: .mintAccent)
                    ScoreBox(value: "\(match.p1Games)", label: "G", color: .mintAccent)
                    ScoreBox(value: pointDisplay(match.p1Points, opponentPoints: match.p2Points, isTieBreak: match.isTieBreak, tieBreakPoints: match.tieBreakP1Points, advantageScoring: matchConfig(match).advantageScoring), label: "P", color: .mintAccent, isServing: isPlayerServing(match, player: 1))
                }.frame(maxWidth: .infinity)
                Spacer().frame(width: DesignSystem.Spacing.lg)
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ScoreBox(value: pointDisplay(match.p2Points, opponentPoints: match.p1Points, isTieBreak: match.isTieBreak, tieBreakPoints: match.tieBreakP2Points, advantageScoring: matchConfig(match).advantageScoring), label: "P", color: .orangeAccent, isServing: isPlayerServing(match, player: 2))
                    ScoreBox(value: "\(match.p2Games)", label: "G", color: .orangeAccent)
                    ScoreBox(value: "\(match.p2Sets)", label: "S", color: .orangeAccent)
                }.frame(maxWidth: .infinity)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Colors.courtMid)
    }
    
    private func playerNameView(_ player: Player, color: Color, isServing: Bool, onLongPress: @escaping () -> Void) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(player.name)
                .font(DesignSystem.Typography.headlineMedium)
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
            if isServing {
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)
                    .symbolEffect(.bounce, options: .repeating)
            }
        }
        .frame(maxWidth: .infinity, alignment: color == .mintAccent ? .trailing : .leading)
        .contentShape(Rectangle())
        .onLongPressGesture { onLongPress() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(player.name)\(isServing ? ", serving" : "")")
        .accessibilityHint("Double tap to edit name")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Player Action Card
    
    private func playerActionCard(player: Player, color: Color, isServing: Bool) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text(player.name.uppercased())
                    .font(DesignSystem.Typography.captionSmall)
                    .bold()
                    .foregroundStyle(DesignSystem.Colors.gray500)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if isServing {
                    Image(systemName: "tennisball.fill")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundStyle(color)
                        .symbolEffect(.bounce, options: .repeating)
                        .accessibilityHidden(true)
                }
                Spacer()
            }
            Button {
                HapticManager.impact(.light)
                recordPoint(player: player, outcome: .winner, note: "")
            } label: {
                Label("Quick Point", systemImage: "plus.circle.fill")
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(color)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            }
            .disabled(currentMatch?.isPaused ?? false)
            .buttonStyle(PrimaryButtonStyle(color: color))
            .accessibilityLabel("Quick point for \(player.name)")
            
            Button {
                HapticManager.impact(.medium)
                pendingPlayer = player
            } label: {
                Label("Add Details", systemImage: "info.circle")
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(color.opacity(0.15))
                    .foregroundStyle(color)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            }
            .disabled(currentMatch?.isPaused ?? false)
            .buttonStyle(SecondaryButtonStyle(color: color))
            .accessibilityLabel("Add detailed point for \(player.name)")
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Live Ticker
    
    private func liveTicker(_ match: Match) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("RECENT POINTS")
                .font(DesignSystem.Typography.captionSmall)
                .bold()
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Colors.gray500)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(match.pointEvents.reversed().prefix(5)) { event in
                    let accentColor = event.player == match.playerOne ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.orangeAccent
                    HStack(spacing: DesignSystem.Spacing.xxs) {
                        Text(event.player.name.prefix(1))
                            .font(DesignSystem.Typography.labelSmall)
                            .bold()
                            .foregroundStyle(.black)
                        Image(systemName: event.outcome.icon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(event.outcome.color)
                    }
                    .font(DesignSystem.Typography.labelSmall)
                    .bold()
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [accentColor, accentColor.opacity(0.8)]),
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, DesignSystem.Spacing.lg)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [DesignSystem.Colors.courtMid, DesignSystem.Colors.courtDark]),
                startPoint: .top, endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
    }
    
    // MARK: - Match Management
    
    private func startNewMatch(p1: Player, p2: Player, firstServer: Int) {
        // Match Lock: never start over a live match (reset or complete it first).
        guard currentMatch == nil else {
            print("🔒 startNewMatch ignored: match already in progress")
            return
        }
        let newMatch = Match(
            playerOne: p1,
            playerTwo: p2,
            format: configuration.formatText,
            location: location,
            setLength: configuration.setLength,
            tieBreakLength: configuration.tieBreakLength,
            firstServer: firstServer
        )
        modelContext.insert(newMatch)
        
        do {
            try modelContext.save()
            print("✅ Match saved successfully")
        } catch {
            print("❌ Database error: \(error.localizedDescription)")
        }
        
        ActivityManager.shared.startActivity(
            playerOne: p1.name,
            playerTwo: p2.name,
            p1Score: "Love",
            p2Score: "Love",
            p1Sets: 0,
            p2Sets: 0,
            p1Games: 0,
            p2Games: 0,
            isTieBreak: false,
            status: "Set in progress"
        )
        // HealthKit: an iPhone-started match logs a tennis workout even with no Watch.
        PhoneWorkoutManager.shared.startTennisWorkout()
        WatchBridge.shared.updateWatchState(data: watchStatePayload(match: newMatch))
        showingSetup = false
    }
    
    private func recordPoint(player: Player, outcome: PointOutcome, note: String) {
        guard let match = currentMatch else { return }
        guard !match.isPaused else { return }
        
        let event = PointEvent(player: player, outcome: outcome, note: note)
        match.pointEvents.append(event)
        
        // Snapshot BEFORE changes for undo
        let snapshot = match.createSnapshot()
        
        let playerIndex = player == match.playerOne ? 1 : 2
        let config = matchConfig(match)
        let changes = TennisEngine.processPoint(
            for: playerIndex,
            match: match,
            config: config,
            firstServer: match.firstServer
        )
        
        // Push undo actions for each state change
        if changes.gameWon != nil {
            match.pushUndoAction(UndoAction(type: .game, player: changes.gameWon, previousState: snapshot, timestamp: Date()))
            HapticManager.impact(.heavy)
            HapticManager.notification(.success)
        } else {
            match.pushUndoAction(UndoAction(type: .point, player: playerIndex, previousState: snapshot, timestamp: Date()))
            HapticManager.impact(.light)
        }
        
        if changes.tieBreakStarted {
            match.pushUndoAction(UndoAction(type: .tieBreakStart, player: nil, previousState: snapshot, timestamp: Date()))
        }
        
        if changes.setWon != nil || changes.tieBreakWonBy != nil {
            match.pushUndoAction(UndoAction(type: .set, player: changes.setWon ?? changes.tieBreakWonBy, previousState: snapshot, timestamp: Date()))
            HapticManager.notification(.success)
        }
        
        if changes.matchWon {
            HapticManager.notification(.success)
            // THE HOOK — To-Do #2: the instant a `Match` is decided, hand it to
            // the bracket orchestor. It records the result onto the scheduled
            // fixture, auto-advances the knockout winner into the next round
            // (walking any chained byes), and flags the champion. SwiftData save
            // lives here; the caller stays on the scoring main thread.
            // Live mirror (To-Do #2.5): the instant the deciding point lands, the
            // final live `setScores` is mirrored onto the bracket fixture's
            // scoreLine so the bracket shows the true closing line, then the
            // completion hook records the winner + advances the champion.
            TournamentManager.shared.handleMatchUpdate(match, in: modelContext)
            TournamentManager.shared.handleMatchCompletion(match, in: modelContext)
            try? modelContext.save()
            // Professional Result Splash (phone- AND watch-originated completions
            // both flow through here) + Match Complete push notification.
            let finishedMatch = match
            DispatchQueue.main.async {
                matchForResults = finishedMatch
                showingResults = true
            }
            let winner = match.winnerName
            let loser = winner == match.playerOne.name ? match.playerTwo.name : match.playerOne.name
            NotificationManager.shared.sendMatchEndNotification(winner: winner, loser: loser)
            // HealthKit: match over means workout over (iPhone-owned session).
            PhoneWorkoutManager.shared.endWorkout()
            // Instant sync: dedicated MATCH_COMPLETE event so the Watch flips
            // to Victory immediately (in addition to the state push below).
            WatchBridge.shared.send([
                "event": "MATCH_COMPLETE",
                "matchID": match.matchID,
                "playerOne": match.playerOne.name,
                "playerTwo": match.playerTwo.name,
                "p1Sets": match.p1Sets,
                "p2Sets": match.p2Sets,
                "matchWinner": winner == match.playerOne.name ? 1 : 2,
                "avgHeartRate": match.avgHeartRate,
                "totalCalories": match.totalCalories
            ])
            // Clean exit: deliver the FINAL state (winner + final score +
            // "Match Complete") as the activity's last frame, then dismiss.
            // Points below are post-reset finals, so they read clean.
            ActivityManager.shared.stopActivity(finalState: MatchAttributes.ContentState(
                p1Score: pointDisplay(match.p1Points, opponentPoints: match.p2Points, isTieBreak: match.isTieBreak, tieBreakPoints: match.tieBreakP1Points, advantageScoring: config.advantageScoring),
                p2Score: pointDisplay(match.p2Points, opponentPoints: match.p1Points, isTieBreak: match.isTieBreak, tieBreakPoints: match.tieBreakP2Points, advantageScoring: config.advantageScoring),
                p1Sets: match.p1Sets,
                p2Sets: match.p2Sets,
                p1Games: match.p1Games,
                p2Games: match.p2Games,
                isTieBreak: false,
                status: "Match Complete • \(winner) 🏆",
                p1Serving: false,
                p2Serving: false
            ))
            pushWatchUpdate()
        }
        
        // Check side switch after point
        checkSideSwitch(match: match)
        
        // Live Activity refreshes only while the match is live; a completed
        // match's activity was ended above (pushWatchUpdate already sent finals).
        if !changes.matchWon {
            updateActivity(match: match)
        }
    }
    
    private func undoPoint(match: Match) {
        guard let lastEvent = match.pointEvents.last else { return }
        match.pointEvents.removeLast()
        if lastEvent.player == match.playerOne { match.p1Points -= 1 } else { match.p2Points -= 1 }
        updateActivity(match: match)
        HapticManager.impact(.medium)
    }
    
    private func updateActivity(match: Match) {
        let config = matchConfig(match)
        let p1Serving = isPlayerServing(match, player: 1)
        let p2Serving = isPlayerServing(match, player: 2)
        ActivityManager.shared.updateActivity(
            p1Score: pointDisplay(match.p1Points, opponentPoints: match.p2Points, isTieBreak: match.isTieBreak, tieBreakPoints: match.tieBreakP1Points, advantageScoring: config.advantageScoring),
            p2Score: pointDisplay(match.p2Points, opponentPoints: match.p1Points, isTieBreak: match.isTieBreak, tieBreakPoints: match.tieBreakP2Points, advantageScoring: config.advantageScoring),
            p1Sets: match.p1Sets, p2Sets: match.p2Sets, p1Games: match.p1Games, p2Games: match.p2Games, isTieBreak: match.isTieBreak,
            status: matchStatusText(match),
            p1Serving: p1Serving, p2Serving: p2Serving
        )
        WatchBridge.shared.updateWatchState(data: watchStatePayload(match: match))
    }
    
    private func pushCurrentStateToWatch() {
        if let match = currentMatch {
            WatchBridge.shared.updateWatchState(data: watchStatePayload(match: match))
        } else {
            stateSeqCounter += 1
            WatchBridge.shared.updateWatchState(data: [
                "event": "stateUpdate",
                "ts": Date().timeIntervalSince1970,
                "seq": stateSeqCounter,
                "hasActiveMatch": false,
                "roster": rosterPlayers.map { $0.name },
                "currentUser": rosterPlayers.first(where: { $0.isCurrentUser })?.name ?? ""
            ])
        }
    }
    
    private func pushWatchUpdate() {
        if let match = currentMatch {
            WatchBridge.shared.updateWatchState(data: watchStatePayload(match: match))
        }
    }
    
    private func watchStatePayload(match: Match, gameWon: Int? = nil) -> [String: Any] {
        // Repair legacy rows that predate cross-device sync identity.
        if match.matchID.isEmpty {
            match.matchID = UUID().uuidString
            try? modelContext.save()
        }
        let config = matchConfig(match)
        let p1Serving = isPlayerServing(match, player: 1)
        let p2Serving = isPlayerServing(match, player: 2)
        
        // Check if we should prompt for side switch
        let shouldPromptSideSwitch = match.shouldPromptSideSwitch && !match.isPaused
        
        var payload: [String: Any] = [
            "event": "stateUpdate",
            "ts": Date().timeIntervalSince1970,
            "seq": stateSeqCounter,
            "matchID": match.matchID,
            "roster": rosterPlayers.map { $0.name },
            "currentUser": rosterPlayers.first(where: { $0.isCurrentUser })?.name ?? "",
            "playerOne": match.playerOne.name,
            "playerTwo": match.playerTwo.name,
            "p1Score": pointDisplay(match.p1Points, opponentPoints: match.p2Points, isTieBreak: match.isTieBreak, tieBreakPoints: match.tieBreakP1Points, advantageScoring: config.advantageScoring),
            "p2Score": pointDisplay(match.p2Points, opponentPoints: match.p1Points, isTieBreak: match.isTieBreak, tieBreakPoints: match.tieBreakP2Points, advantageScoring: config.advantageScoring),
            "p1Sets": match.p1Sets,
            "p2Sets": match.p2Sets,
            "p1Games": match.p1Games,
            "p2Games": match.p2Games,
            "isTieBreak": match.isTieBreak,
            "status": matchStatusText(match),
            "hasActiveMatch": !match.isCompleted,
            "p1Serving": p1Serving,
            "p2Serving": p2Serving,
            "setLength": config.setLength,
            "tieBreakLength": config.tieBreakLength,
            "advantageScoring": config.advantageScoring,
            "firstServer": match.firstServer,
            "tieBreakP1Points": match.tieBreakP1Points,
            "tieBreakP2Points": match.tieBreakP2Points,
            "isPaused": match.isPaused,
            "elapsedTime": match.elapsedTime,
            "undoStackCount": match.undoStack.count,
            "showSideSwitchPrompt": shouldPromptSideSwitch
        ]
        if let gameWon {
            payload["gameWon"] = gameWon
        }
        if match.isCompleted {
            payload["matchWon"] = true
            payload["matchWinner"] = match.winnerName == match.playerOne.name ? 1 : 2
        }
        stateSeqCounter += 1
        return payload
    }
    
    private var emptyStateUI: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "tennisball.fill")
                .font(.system(size: 80))
                .foregroundStyle(DesignSystem.Colors.mintAccent)
            Text("No Active Match")
                .font(DesignSystem.Typography.displayMedium)
                .bold()
                .foregroundStyle(.white)
            Button("Start Match") {
                selectedP1 = nil
                selectedP2 = nil
                showingSetup = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.captionSmall)
            .bold()
            .tracking(1.5)
            .foregroundStyle(DesignSystem.Colors.gray500)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, DesignSystem.Spacing.md)
    }
}