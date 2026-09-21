import Foundation
import ActivityKit

@MainActor
final class ActivityManager {
    static let shared = ActivityManager()
    private init() {}

    func startActivity(playerOne: String, playerTwo: String, p1Score: String, p2Score: String, p1Sets: Int, p2Sets: Int, p1Games: Int, p2Games: Int, isTieBreak: Bool, status: String) {
        let attributes = MatchAttributes(playerOne: playerOne, playerTwo: playerTwo)
        let contentState = MatchAttributes.ContentState(
            p1Score: p1Score, p2Score: p2Score,
            p1Sets: p1Sets, p2Sets: p2Sets,
            p1Games: p1Games, p2Games: p2Games,
            isTieBreak: isTieBreak, status: status,
            p1Serving: true, p2Serving: false // Player 1 serves first by default
        )
        do {
            _ = try Activity.request(attributes: attributes, content: .init(state: contentState, staleDate: nil))
        } catch { print("Error: \(error.localizedDescription)") }
    }

    func updateActivity(p1Score: String, p2Score: String, p1Sets: Int, p2Sets: Int, p1Games: Int, p2Games: Int, isTieBreak: Bool, status: String, p1Serving: Bool = false, p2Serving: Bool = false) {
        let updatedState = MatchAttributes.ContentState(
            p1Score: p1Score, p2Score: p2Score,
            p1Sets: p1Sets, p2Sets: p2Sets,
            p1Games: p1Games, p2Games: p2Games,
            isTieBreak: isTieBreak, status: status,
            p1Serving: p1Serving, p2Serving: p2Serving
        )
        Task {
            for activity in Activity<MatchAttributes>.activities {
                await activity.update(ActivityContent(state: updatedState, staleDate: nil))
            }
        }
    }

    /// Ends the Live Activity. When a final state is provided, it is delivered
    /// as the activity's last frame (winner + final score) before dismissal,
    /// so the Dynamic Island never shows stale or empty content.
    func stopActivity(finalState: MatchAttributes.ContentState? = nil) {
        Task {
            for activity in Activity<MatchAttributes>.activities {
                if let finalState {
                    await activity.end(
                        ActivityContent(state: finalState, staleDate: nil),
                        dismissalPolicy: .immediate
                    )
                } else {
                    await activity.end(activity.content, dismissalPolicy: .immediate)
                }
            }
        }
    }
}