import Foundation
import ActivityKit

struct MatchAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var p1Score: String
        var p2Score: String
        var p1Sets: Int
        var p2Sets: Int
        var p1Games: Int
        var p2Games: Int
        var isTieBreak: Bool
        var status: String
        var p1Serving: Bool
        var p2Serving: Bool
    }
    var playerOne: String
    var playerTwo: String
}