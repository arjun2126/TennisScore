import ActivityKit
import WidgetKit
import SwiftUI

struct TennisScoreWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchAttributes.self) { context in
            // LOCK SCREEN
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.playerOne)
                        .font(.headline).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    Text(context.state.p1Score).font(.title2).bold().foregroundStyle(Color.mintAccent)
                }
                .frame(maxWidth: .infinity, alignment: .leading) // SAFE: Pushes column, not text element
                
                Spacer()
                
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("S").font(.system(size: 8)).bold().foregroundStyle(.secondary)
                        Text("\(context.state.p1Sets)-\(context.state.p2Sets)").font(.system(size: 12)).bold().foregroundStyle(.white)
                    }
                    HStack(spacing: 4) {
                        Text("G").font(.system(size: 8)).bold().foregroundStyle(.secondary)
                        Text("\(context.state.p1Games)-\(context.state.p2Games)").font(.system(size: 12)).bold().foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .fixedSize() // SAFE: Guards middle dimension calculations
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.attributes.playerTwo)
                        .font(.headline).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    Text(context.state.p2Score).font(.title2).bold().foregroundStyle(Color.orangeAccent)
                }
                .frame(maxWidth: .infinity, alignment: .trailing) // SAFE: Pushes column, not text element
            }
            .padding()
            .background(Color.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // DYNAMIC ISLAND EXPANDED VIEW — Unified layout structure to eliminate overextension bugs
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 10) {
                        
                        // ROW 1: Names and Game Point Scores (Perfectly balanced)
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(context.attributes.playerOne)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                Text(context.state.p1Score)
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundStyle(Color.mintAccent)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(context.attributes.playerTwo)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                Text(context.state.p2Score)
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundStyle(Color.orangeAccent)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.horizontal, 4)
                        
                        // ROW 2: Match Metadata and Stats (Contains all tiebreak, game, and set logic intact)
                        HStack(alignment: .center) {
                            if context.state.isTieBreak {
                                Text("TIEBREAK")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(.yellow)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.yellow.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                            
                            HStack(spacing: 10) {
                                Text("S: \(context.state.p1Sets)-\(context.state.p2Sets)")
                                    .font(.system(size: 10, weight: .bold))
                                Text("G: \(context.state.p1Games)-\(context.state.p2Games)")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                            
                            Spacer()
                            
                            Text(context.state.status)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.top, 6)
                }
            } compactLeading: {
                Text(context.state.p1Score).font(.system(size: 12, weight: .bold)).foregroundStyle(Color.mintAccent)
            } compactTrailing: {
                Text(context.state.p2Score).font(.system(size: 12, weight: .bold)).foregroundStyle(Color.orangeAccent)
            } minimal: {
                Text("\(context.state.p1Sets)-\(context.state.p2Sets)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
            }
        }
    }
}
