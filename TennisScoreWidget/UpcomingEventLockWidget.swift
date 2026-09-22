import WidgetKit
import SwiftUI

struct UpcomingEventLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Vantage.UpcomingEventLock", provider: UpcomingEventLockProvider()) { entry in
            UpcomingEventLockView(entry: entry)
        }
        .configurationDisplayName("Upcoming Event")
        .description("The next scheduled event.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct UpcomingEventLockEntry: TimelineEntry {
    let date: Date
    let event: WidgetEventEntry?
}

class UpcomingEventLockProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingEventLockEntry {
        UpcomingEventLockEntry(date: .now, event: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (UpcomingEventLockEntry) -> Void) {
        completion(UpcomingEventLockEntry(date: .now, event: WidgetKitHelper.readEvents()?.first))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingEventLockEntry>) -> Void) {
        completion(Timeline(entries: [UpcomingEventLockEntry(date: .now, event: WidgetKitHelper.readEvents()?.first)], policy: .after(Date().addingTimeInterval(300))))
    }
}

struct UpcomingEventLockView: View {
    let entry: UpcomingEventLockEntry
    var body: some View {
        HStack(spacing: 4) {
            if let event = entry.event {
                Text(event.name)
                    .font(.caption2).bold().lineLimit(1)
                Text(event.location)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            } else {
                Text("No event")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
