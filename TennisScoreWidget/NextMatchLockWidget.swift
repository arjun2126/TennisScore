import WidgetKit
import SwiftUI

struct NextMatchLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Vantage.NextMatchLock", provider: NextMatchLockProvider()) { entry in
            NextMatchLockView(entry: entry)
        }
        .configurationDisplayName("Next Match")
        .description("The next scheduled match.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct NextMatchLockEntry: TimelineEntry {
    let date: Date
    let match: WidgetMatchEntry?
}

class NextMatchLockProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextMatchLockEntry {
        NextMatchLockEntry(date: .now, match: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (NextMatchLockEntry) -> Void) {
        completion(NextMatchLockEntry(date: .now, match: WidgetKitHelper.readMatch()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextMatchLockEntry>) -> Void) {
        completion(Timeline(entries: [NextMatchLockEntry(date: .now, match: WidgetKitHelper.readMatch())], policy: .after(Date().addingTimeInterval(300))))
    }
}

struct NextMatchLockView: View {
    let entry: NextMatchLockEntry
    var body: some View {
        HStack(spacing: 4) {
            if let match = entry.match {
                Text("\(match.playerOne) vs \(match.playerTwo)")
                    .font(.caption2).bold().lineLimit(1)
                Text("\(match.p1Score)–\(match.p2Score)")
                    .font(.caption)
            } else {
                Text("No match")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
