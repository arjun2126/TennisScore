import WidgetKit
import SwiftUI

struct ThisWeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Vantage.ThisWeek", provider: ThisWeekProvider()) { entry in
            ThisWeekView(entry: entry)
        }
        .configurationDisplayName("This Week")
        .description("Upcoming matches and events this week.")
        .supportedFamilies([.systemMedium])
    }
}

struct ThisWeekEntry: TimelineEntry {
    let date: Date
    let upcomingEvents: [WidgetEventEntry]
}

class ThisWeekProvider: TimelineProvider {
    func placeholder(in context: Context) -> ThisWeekEntry {
        ThisWeekEntry(date: .now, upcomingEvents: [])
    }
    func getSnapshot(in context: Context, completion: @escaping (ThisWeekEntry) -> Void) {
        completion(ThisWeekEntry(date: .now, upcomingEvents: WidgetKitHelper.readEvents() ?? []))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ThisWeekEntry>) -> Void) {
        completion(Timeline(entries: [ThisWeekEntry(date: .now, upcomingEvents: WidgetKitHelper.readEvents() ?? [])], policy: .after(Date().addingTimeInterval(600))))
    }
}

struct ThisWeekView: View {
    let entry: ThisWeekEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("This Week")
                .font(.caption).bold()
            if entry.upcomingEvents.isEmpty {
                Text("No events this week")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(entry.upcomingEvents.prefix(4), id: \.name) { event in
                    HStack {
                        Text(event.name)
                            .font(.caption).bold().lineLimit(1)
                        Spacer()
                        Text(event.startDate.formatted(.dateTime.month().day()))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
