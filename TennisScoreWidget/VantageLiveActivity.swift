//
//  VantageLiveActivity.swift
//  VantageWidget
//

import ActivityKit
import WidgetKit
import SwiftUI

struct VantageLiveActivityAttributes: ActivityAttributes {
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

struct VantageLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VantageLiveActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(context.attributes.playerOne)
                                .font(.caption).bold()
                            if context.state.p1Serving {
                                Image(systemName: "tennisball.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.mint)
                                    .symbolEffect(.bounce, options: .repeating)
                            }
                        }
                        Text("\(context.state.p1Sets) Sets")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(context.attributes.playerTwo)
                                .font(.caption).bold()
                            if context.state.p2Serving {
                                Image(systemName: "tennisball.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.orange)
                                    .symbolEffect(.bounce, options: .repeating)
                            }
                        }
                        Text("\(context.state.p2Sets) Sets")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text("\(context.state.p1Score) - \(context.state.p2Score)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                        Text("\(context.state.p1Games) - \(context.state.p2Games) Games")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.status)
                            .font(.caption2).bold().foregroundStyle(.mint)
                        if context.state.isTieBreak {
                            Text("TIE-BREAK")
                                .font(.caption2).bold().foregroundStyle(.yellow)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Color.yellow.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
            } compactLeading: {
                Text("\(context.state.p1Score)")
                    .font(.caption).bold().foregroundStyle(context.state.p1Serving ? .mint : .white)
            } compactTrailing: {
                Text("\(context.state.p2Score)")
                    .font(.caption).bold().foregroundStyle(context.state.p2Serving ? .orange : .white)
            } minimal: {
                Text("\(context.state.p1Score)-\(context.state.p2Score)")
                    .font(.caption).bold()
            }
            .keylineTint(.mint)
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<VantageLiveActivityAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            // Player names and sets
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(context.attributes.playerOne)
                            .font(.caption).bold().foregroundStyle(.white)
                        if context.state.p1Serving {
                            Image(systemName: "tennisball.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.mint)
                                .symbolEffect(.bounce, options: .repeating)
                        }
                    }
                    Text("\(context.state.p1Sets) Sets")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Score
                VStack(spacing: 4) {
                    Text("\(context.state.p1Score) - \(context.state.p2Score)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("\(context.state.p1Games) - \(context.state.p2Games) Games")
                        .font(.caption).foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(context.attributes.playerTwo)
                            .font(.caption).bold().foregroundStyle(.white)
                        if context.state.p2Serving {
                            Image(systemName: "tennisball.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.orange)
                                .symbolEffect(.bounce, options: .repeating)
                        }
                    }
                    Text("\(context.state.p2Sets) Sets")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            
            // Status
            Text(context.state.status)
                .font(.caption2).bold().foregroundStyle(.mint)
                .frame(maxWidth: .infinity, alignment: .center)
            
            if context.state.isTieBreak {
                Text("TIE-BREAK")
                    .font(.caption2).bold().foregroundStyle(.yellow)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color.black)
        .activityBackgroundTint(Color.black)
        .activitySystemActionForegroundColor(.mint)
    }
}