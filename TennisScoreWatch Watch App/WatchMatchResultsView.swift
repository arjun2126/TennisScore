import SwiftUI
import WatchKit

/// First-class companion "Victory" screen — same brand as the iPhone splash:
/// courtDark stage, mintAccent glory, trophy, winner, final score, summary.
struct WatchMatchResultsView: View {
    let match: Match
    var onNewMatch: () -> Void
    var onDone: () -> Void

    private var winnerIsP1: Bool { match.winnerName == match.playerOne.name }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.10, blue: 0.13).ignoresSafeArea()
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(red: 1.00, green: 0.75, blue: 0.10))
                        .shadow(color: Color(red: 1.00, green: 0.75, blue: 0.10).opacity(0.5), radius: 10)

                    Text("MATCH COMPLETE")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Color.gray500)

                    Text(match.winnerName.isEmpty ? "Draw" : watchDisplayName(match.winnerName))
                        .font(.footnote)
                        .bold()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                    Text("\(match.p1Sets) - \(match.p2Sets)")
                        .font(Typography.scoreSmall)
                        .bold()
                        .foregroundStyle(Color.mintAccent)

                    if !match.setScores.isEmpty {
                        Text(match.setScores)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gray500)
                        Text(match.formattedElapsedTime)
                            .font(.caption)
                            .foregroundStyle(Color.gray500)
                    }

                    if !match.format.isEmpty {
                        Text(match.format)
                            .font(.caption)
                            .foregroundStyle(Color.gray500)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: {
                        WKInterfaceDevice.current().play(.click)
                        onNewMatch()
                    }) {
                        Label("New Match", systemImage: "plus.circle.fill")
                            .font(.footnote)
                            .bold()
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Color.mintAccent)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        WKInterfaceDevice.current().play(.click)
                        onDone()
                    }) {
                        Text("Done")
                            .font(.footnote)
                            .bold()
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(Color.white.opacity(0.15))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            WKInterfaceDevice.current().play(.success)
        }
    }
}

#Preview {
    WatchMatchResultsView(
        match: {
            let p1 = Player(name: "Player 1")
            let p2 = Player(name: "Player 2")
            let m = Match(playerOne: p1, playerTwo: p2, format: "Best of 3 • Set to 6 • Tie-break to 7 • Advantage", setLength: 6, tieBreakLength: 7)
            m.winnerName = "Player 1"
            m.setScores = "6-4, 6-3"
            m.p1Sets = 2
            m.isCompleted = true
            return m
        }(),
        onNewMatch: {},
        onDone: {}
    )
}
