import Foundation
import ActivityKit

class ActivityManager {
    static let shared = ActivityManager()
    private init() {}

    func startActivity(playerOne: String, playerTwo: String, p1Score: String, p2Score: String, p1Sets: Int, p2Sets: Int, p1Games: Int, p2Games: Int, isTieBreak: Bool, status: String) {
        let attributes = MatchAttributes(playerOne: playerOne, playerTwo: playerTwo)
        let contentState = MatchAttributes.ContentState(p1Score: p1Score, p2Score: p2Score, p1Sets: p1Sets, p2Sets: p2Sets, p1Games: p1Games, p2Games: p2Games, isTieBreak: isTieBreak, status: status)
        do {
            _ = try Activity.request(attributes: attributes, content: .init(state: contentState, staleDate: nil))
        } catch { print("Error: \(error.localizedDescription)") }
    }

    func updateActivity(p1Score: String, p2Score: String, p1Sets: Int, p2Sets: Int, p1Games: Int, p2Games: Int, isTieBreak: Bool, status: String) {
        let updatedState = MatchAttributes.ContentState(p1Score: p1Score, p2Score: p2Score, p1Sets: p1Sets, p2Sets: p2Sets, p1Games: p1Games, p2Games: p2Games, isTieBreak: isTieBreak, status: status)
        Task {
            for activity in Activity<MatchAttributes>.activities {
                await activity.update(using: updatedState)
            }
        }
    }

    func stopActivity() {
        Task {
            for activity in Activity<MatchAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
