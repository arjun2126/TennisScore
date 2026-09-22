import WidgetKit
import SwiftUI

struct NextMatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Vantage.NextMatch", provider: NextMatchProvider()) { entry in
            NextMatchView(entry: entry)
        }
        .configurationDisplayName("Next Match")
        .description("The next scheduled match.")
        .supportedFamilies([.systemSmall])
    }
}

struct NextMatchEntry: TimelineEntry {
    let date: Date
    let match: WidgetMatchEntry?
}

class NextMatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextMatchEntry {
        NextMatchEntry(date: .now, match: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (NextMatchEntry) -> Void) {
        completion(NextMatchEntry(date: .now, match: WidgetKitHelper.readMatch()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextMatchEntry>) -> Void) {
        completion(Timeline(entries: [NextMatchEntry(date: .now, match: WidgetKitHelper.readMatch())], policy: .after(Date().addingTimeInterval(300))))
    }
}

struct NextMatchView: View {
    let entry: NextMatchEntry
    var body: some View {
        VStack(spacing: 3) {
            if let match = entry.match {
                Text(match.isActive ? "LIVE" : "NEXT")
                    .font(.caption2).bold()
                Text("\(match.playerOne) vs \(match.playerTwo)")
                    .font(.caption).bold().lineLimit(1)
                Text("\(match.p1Score) – \(match.p2Score)")
                    .font(.title3).bold()
                Text(match.isTieBreak ? "Tie-break" : "Set \(match.p1Sets)–\(match.p2Sets)")
                    .font(.caption2)
            } else {
                Text("No match")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Tap to start")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(4)
    }
}
