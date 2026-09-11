//
//  TennisScoreWidgetLiveActivity.swift
//  TennisScoreWidget
//
//  Created by Arjun Subramanya on 2026-09-11.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TennisScoreWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TennisScoreWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TennisScoreWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension TennisScoreWidgetAttributes {
    fileprivate static var preview: TennisScoreWidgetAttributes {
        TennisScoreWidgetAttributes(name: "World")
    }
}

extension TennisScoreWidgetAttributes.ContentState {
    fileprivate static var smiley: TennisScoreWidgetAttributes.ContentState {
        TennisScoreWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TennisScoreWidgetAttributes.ContentState {
         TennisScoreWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TennisScoreWidgetAttributes.preview) {
   TennisScoreWidgetLiveActivity()
} contentStates: {
    TennisScoreWidgetAttributes.ContentState.smiley
    TennisScoreWidgetAttributes.ContentState.starEyes
}
