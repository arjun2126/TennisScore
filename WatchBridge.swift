import Foundation
import Combine
import WatchConnectivity

#if os(iOS) || os(watchOS)
nonisolated struct MatchState {
    var playerOne: String
    var playerTwo: String
    var p1Score: String
    var p2Score: String
    var p1Sets: Int
    var p2Sets: Int
    var p1Games: Int
    var p2Games: Int
    var isTieBreak: Bool
    var status: String
    var hasActiveMatch: Bool
    var gameWon: Int?
    var matchWon: Bool
    var matchWinner: Int?
    var p1Serving: Bool
    var p2Serving: Bool
    var setLength: Int
    var tieBreakLength: Int
    var advantageScoring: Bool
    var firstServer: Int
    var tieBreakP1Points: Int
    var tieBreakP2Points: Int
    var isPaused: Bool
    var elapsedTime: TimeInterval
    var undoStackCount: Int
    var showSideSwitchPrompt: Bool
    /// Tournament context for the Victory gate (“Event Name 🏆”). Plain watch-
    /// safe strings parsed from the phone payload; empty for free-play matches.
    var tournamentName: String = ""
    var tournamentMatchID: String = ""
    /// Monotonic sequence: the phone stamps every full-state message so the
    /// Watch never applies a stale/out-of-order copy.
    var stateSeq: Int

    init(playerOne: String = "P1", playerTwo: String = "P2", p1Score: String = "", p2Score: String = "",
         p1Sets: Int = 0, p2Sets: Int = 0, p1Games: Int = 0, p2Games: Int = 0,
         isTieBreak: Bool = false, status: String = "", hasActiveMatch: Bool = false,
         gameWon: Int? = nil, matchWon: Bool = false, matchWinner: Int? = nil,
         p1Serving: Bool = false, p2Serving: Bool = false,
         setLength: Int = 6, tieBreakLength: Int = 7, advantageScoring: Bool = true,
         firstServer: Int = 1, tieBreakP1Points: Int = 0, tieBreakP2Points: Int = 0,
         isPaused: Bool = false, elapsedTime: TimeInterval = 0, undoStackCount: Int = 0,
         showSideSwitchPrompt: Bool = false, stateSeq: Int = 0) {
        self.playerOne = playerOne
        self.playerTwo = playerTwo
        self.p1Score = p1Score
        self.p2Score = p2Score
        self.p1Sets = p1Sets
        self.p2Sets = p2Sets
        self.p1Games = p1Games
        self.p2Games = p2Games
        self.isTieBreak = isTieBreak
        self.status = status
        self.hasActiveMatch = hasActiveMatch
        self.gameWon = gameWon
        self.matchWon = matchWon
        self.matchWinner = matchWinner
        self.p1Serving = p1Serving
        self.p2Serving = p2Serving
        self.setLength = setLength
        self.tieBreakLength = tieBreakLength
        self.advantageScoring = advantageScoring
        self.firstServer = firstServer
        self.tieBreakP1Points = tieBreakP1Points
        self.tieBreakP2Points = tieBreakP2Points
        self.isPaused = isPaused
        self.elapsedTime = elapsedTime
        self.undoStackCount = undoStackCount
        self.showSideSwitchPrompt = showSideSwitchPrompt
        self.stateSeq = stateSeq
    }

    var pointScore: String { "\(p1Score) - \(p2Score)" }
    var setScore: String { "\(p1Sets)-\(p2Sets)" }
    var gameScore: String { "\(p1Games)-\(p2Games)" }
    
    /// Current match state enum for Watch UI.
    /// matchWon wins: a just-finished match reports hasActiveMatch=false AND
    /// matchWon=true, and the Victory screen must take precedence.
    var uiState: WatchUIState {
        if matchWon { return .matchComplete }
        if !hasActiveMatch { return .setup }
        return .active
    }
}

enum WatchUIState {
    case setup
    case active
    case matchComplete
}

@MainActor
final class WatchBridge: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchBridge()
    nonisolated static let watchActionNotification = Notification.Name("WatchAction")
    nonisolated static let rosterCacheKey = "tennis_roster_cache"
    nonisolated static let currentUserCacheKey = "tennis_current_user_cache"

    @Published var matchState = MatchState()
    /// Player roster synced from iPhone (falls back to the last cached copy offline).
    @Published var roster: [String] = []
    /// Primary-user ("Me") name synced from iPhone for setup auto-fill.
    @Published var currentUserName: String = ""
    /// Bool gate for the branded "Connecting..." screen: true until a real
    /// state frame arrives or the roster pre-warms (offline show must respect it).
    @Published var isConnecting: Bool = true

    /// Monotonic guard: highest sequence number we've accepted. Messages with
    /// a lower (or equal) sequence CANNOT rewind the score.
    private var lastAppliedSeq: Int = 0
    /// Wall-clock stamp of the last accepted frame; combined with the seq for
    /// a lexicographic (ts, seq) order that survives phone app relaunches.
    private var lastAppliedTS: TimeInterval = 0
    private var lastAppliedMatchID: String = ""

    private override init() {
        super.init()
        roster = UserDefaults.standard.stringArray(forKey: Self.rosterCacheKey) ?? []
        currentUserName = UserDefaults.standard.string(forKey: Self.currentUserCacheKey) ?? ""
        isConnecting = roster.isEmpty && currentUserName.isEmpty
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func send(_ payload: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.isReachable else { return }
        session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }

    /// First-class companion delivery: send instantly when reachable, otherwise
    /// queue via `transferUserInfo` so the system delivers it on reconnect.
    /// Payloads must stay property-list safe (String/Int/Bool/Array/Dictionary).
    func sendOrQueue(_ payload: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    /// Scoring send with delivery receipt: reports transport errors so the
    /// sender (optimistic UI) can roll back. Reachable → sendMessage with an
    /// error handler; unreachable → offline queue (no receipt possible).
    /// Error callbacks arrive off the main thread — hop before touching UI.
    func sendScoring(_ payload: [String: Any], onError: ((Error) -> Void)? = nil) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.isReachable else {
            session.transferUserInfo(payload)
            return
        }
        session.sendMessage(payload, replyHandler: nil) { error in
            onError?(error)
        }
    }

    /// Lightning-fast hot path for real-time scoring: sendMessage ONLY.
    /// updateApplicationContext is deliberately NOT used here — it is
    /// rate-limited/coalesced (seconds of lag) while sendMessage delivers in
    /// milliseconds. Every message carries FULL state, so a dropped message
    /// self-heals on the very next point. transferUserInfo stays reserved for
    /// the offline store-and-forward queue (sendOrQueue), never the hot path.
    func updateWatchState(data: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.isReachable else { return }
        session.sendMessage(data, replyHandler: nil, errorHandler: nil)
    }

    func requestCurrentState() {
        sendPendingRequest(tries: 0)
    }

    private func sendPendingRequest(tries: Int) {
        guard tries < 60 else { return }
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.sendPendingRequest(tries: tries + 1)
            }
            return
        }
        session.sendMessage(["action": "requestState"], replyHandler: nil, errorHandler: nil)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable
        Task { await MainActor.run {
            if isReachable {
                // Recovery: after any "Connection interrupted / will attempt to
                // reconnect" cycle the Watch stood in queue — pull the full
                // state NOW so it never renders stale data.
                requestCurrentState()
                NotificationCenter.default.post(name: Self.watchActionNotification, object: nil, userInfo: ["action": "watchConnected"])
            }
        } }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { await MainActor.run { [weak self] in
            self?.applyStateUpdate(from: applicationContext)
        } }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { await MainActor.run { [weak self] in
            guard let self else { return }
            NotificationCenter.default.post(name: Self.watchActionNotification, object: nil, userInfo: message)
            self.applyStateUpdate(from: message)
        } }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { await MainActor.run { [weak self] in
            guard let self else { return }
            NotificationCenter.default.post(name: Self.watchActionNotification, object: nil, userInfo: message)
            self.applyStateUpdate(from: message)
        } }
        replyHandler(["status": "ok"])
    }

    /// Offline-queued companion messages (transferUserInfo) delivered on reconnect.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { await MainActor.run { [weak self] in
            guard let self else { return }
            NotificationCenter.default.post(name: Self.watchActionNotification, object: nil, userInfo: userInfo)
            self.applyStateUpdate(from: userInfo)
        } }
    }

    func resetMatchState() {
        // Already MainActor: direct assignment, no hop needed.
        self.matchState = MatchState()
    }

    private func applyStateUpdate(from message: [String: Any]) {
        if let roster = message["roster"] as? [String] {
            UserDefaults.standard.set(roster, forKey: Self.rosterCacheKey)
            self.roster = roster
        }
        if let currentUser = message["currentUser"] as? String {
            UserDefaults.standard.set(currentUser, forKey: Self.currentUserCacheKey)
            self.currentUserName = currentUser
        }
        // Instant-sync fast path: a dedicated completion event flips the
        // Watch to Victory immediately, without waiting for a point update.
        if message["event"] as? String == "MATCH_COMPLETE" {
            let finished = MatchState(
                playerOne: message["playerOne"] as? String ?? "P1",
                playerTwo: message["playerTwo"] as? String ?? "P2",
                p1Sets: message["p1Sets"] as? Int ?? 0,
                p2Sets: message["p2Sets"] as? Int ?? 0,
                status: "Match Finished",
                hasActiveMatch: false,
                matchWon: true,
                matchWinner: message["matchWinner"] as? Int
            )
            print("🏆 WatchBridge received MATCH_COMPLETE: \(message)")
            isConnecting = false
            self.matchState = finished
            return
        }
        guard message["event"] as? String == "stateUpdate" else { return }
        isConnecting = false
        // Sequence guard: never accept an out-of-order / stale full-state
        // frame that would yank the score backward. (ts, seq) are compared
        // lexicographically so a phone relaunch (seq reset) still orders by
        // timestamp; a brand-new matchID always supersedes the previous one.
        let ts = message["ts"] as? Double ?? 0
        let seq = message["seq"] as? Int ?? 0
        let matchID = message["matchID"] as? String ?? ""
        if matchID != lastAppliedMatchID {
            lastAppliedMatchID = matchID
            lastAppliedTS = ts
            lastAppliedSeq = seq
        } else if ts > lastAppliedTS || (ts == lastAppliedTS && seq > lastAppliedSeq) {
            lastAppliedTS = ts
            lastAppliedSeq = seq
        } else {
            print("⏭️ WatchBridge dropped stale frame seq=\(seq) ts=\(ts) (lastSeq=\(lastAppliedSeq) ts=\(lastAppliedTS))")
            return
        }
        print("📲 WatchBridge received state: \(message)")
        let newState = MatchState(
            playerOne: message["playerOne"] as? String ?? "P1",
            playerTwo: message["playerTwo"] as? String ?? "P2",
            p1Score: message["p1Score"] as? String ?? "",
            p2Score: message["p2Score"] as? String ?? "",
            p1Sets: message["p1Sets"] as? Int ?? 0,
            p2Sets: message["p2Sets"] as? Int ?? 0,
            p1Games: message["p1Games"] as? Int ?? 0,
            p2Games: message["p2Games"] as? Int ?? 0,
            isTieBreak: message["isTieBreak"] as? Bool ?? false,
            status: message["status"] as? String ?? "",
            hasActiveMatch: message["hasActiveMatch"] as? Bool ?? false,
            gameWon: message["gameWon"] as? Int,
            matchWon: message["matchWon"] as? Bool ?? false,
            matchWinner: message["matchWinner"] as? Int,
            p1Serving: message["p1Serving"] as? Bool ?? false,
            p2Serving: message["p2Serving"] as? Bool ?? false,
            setLength: message["setLength"] as? Int ?? 6,
            tieBreakLength: message["tieBreakLength"] as? Int ?? 7,
            advantageScoring: message["advantageScoring"] as? Bool ?? true,
            firstServer: message["firstServer"] as? Int ?? 1,
            tieBreakP1Points: message["tieBreakP1Points"] as? Int ?? 0,
            tieBreakP2Points: message["tieBreakP2Points"] as? Int ?? 0,
            isPaused: message["isPaused"] as? Bool ?? false,
            elapsedTime: message["elapsedTime"] as? TimeInterval ?? 0,
            undoStackCount: message["undoStackCount"] as? Int ?? 0,
            showSideSwitchPrompt: message["showSideSwitchPrompt"] as? Bool ?? false,
            stateSeq: seq
        )
        self.matchState = newState
    }
}
#endif