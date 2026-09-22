import Foundation
import SwiftData

final class WidgetFeed {
    static let shared = WidgetFeed()
    private let suiteName = "group.com.arjun.TennisScore"

    struct MatchEntry: Codable {
        let playerOne: String
        let playerTwo: String
        let p1Score: String
        let p2Score: String
        let p1Sets: Int
        let p2Sets: Int
        let isTieBreak: Bool
        let date: Date
        let isActive: Bool
    }

    struct EventEntry: Codable {
        let name: String
        let location: String
        let startDate: Date
    }

    private var suite: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    func write(activeMatch: MatchEntry?, upcoming events: [EventEntry]) {
        guard let suite else { return }
        var payload: [String: Any] = [:]
        if let activeMatch {
            payload["activeMatch"] = try? JSONEncoder().encode(activeMatch)
        }
        if !events.isEmpty {
            payload["upcomingEvents"] = try? JSONEncoder().encode(events)
        }
        suite.set(payload, forKey: "vantageWidgetData")
        suite.synchronize()
    }

    func read() -> (activeMatch: MatchEntry?, upcomingEvents: [EventEntry]?) {
        guard let suite,
              let payload = suite.dictionary(forKey: "vantageWidgetData") as? [String: Any],
              let data = payload["activeMatch"] as? Data,
              let match = try? JSONDecoder().decode(MatchEntry.self, from: data)
        else { return (nil, nil) }
        let events: [EventEntry]? = (payload["upcomingEvents"] as? Data)
            .flatMap { try? JSONDecoder().decode([EventEntry].self, from: $0) }
        return (match, events)
    }
}
