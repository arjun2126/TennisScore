import Foundation

struct WidgetMatchEntry: Codable {
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

struct WidgetEventEntry: Codable {
    let name: String
    let location: String
    let startDate: Date
}

enum WidgetKitHelper {
    static let suiteName = "group.com.arjun.TennisScore"
    private static var suite: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
    static func readMatch() -> WidgetMatchEntry? {
        guard let suite,
              let payload = suite.dictionary(forKey: "vantageWidgetData") as? [String: Any],
              let data = payload["activeMatch"] as? Data,
              let match = try? JSONDecoder().decode(WidgetMatchEntry.self, from: data)
        else { return nil }
        return match
    }
    static func readEvents() -> [WidgetEventEntry]? {
        guard let suite,
              let payload = suite.dictionary(forKey: "vantageWidgetData") as? [String: Any],
              let data = payload["upcomingEvents"] as? Data
        else { return nil }
        return try? JSONDecoder().decode([WidgetEventEntry].self, from: data)
    }
}
