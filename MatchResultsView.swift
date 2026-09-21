import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct MatchResultsView: View {
    let match: Match
    var onStartNew: () -> Void
    /// Dismisses the splash and returns to the Home/Score screen (match kept).
    var onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    DesignSystem.Colors.courtDark.ignoresSafeArea()
                    ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Trophy
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(DesignSystem.Colors.warning)
                                .shadow(color: DesignSystem.Colors.warning.opacity(0.5), radius: 20)
                            
                            Text("MATCH COMPLETE")
                                .font(DesignSystem.Typography.captionSmall)
                                .bold()
                                .tracking(4)
                                .foregroundStyle(DesignSystem.Colors.gray500)
                            
                            Text(match.winnerName)
                                .font(DesignSystem.Typography.displayMedium)
                                .bold()
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, DesignSystem.Spacing.xl)
                        
                        // Final Score
                        VStack(spacing: DesignSystem.Spacing.xs) {
                            Text("FINAL SCORE")
                                .font(DesignSystem.Typography.captionSmall)
                                .bold()
                                .foregroundStyle(DesignSystem.Colors.gray500)
                            
                            Text(match.setScores)
                                .font(DesignSystem.Typography.scoreLarge)
                                .bold()
                                .foregroundStyle(DesignSystem.Colors.mintAccent)
                        }
                        .padding(DesignSystem.Spacing.xl)
                        .background(DesignSystem.Colors.glassBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                                .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        
                        // Match Details Card
                        matchDetailsCard
                        
                        // Stats Summary
                        statsSummaryCard
                        
                        Spacer()
                        
                        // Action Buttons
                        VStack(spacing: DesignSystem.Spacing.md) {
                            PDFShareButton(match: match) {
                                Label("Share Result", systemImage: "square.and.arrow.up")
                                    .font(DesignSystem.Typography.labelLarge)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DesignSystem.Spacing.md)
                                    .background(DesignSystem.Colors.info.opacity(0.2))
                                    .foregroundStyle(DesignSystem.Colors.info)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                            }
                            .accessibilityLabel("Share match result as PDF")
                            
                            NavigationLink(destination: StatsView()) {
                                Label("View Career Stats", systemImage: "chart.bar.fill")
                                    .font(DesignSystem.Typography.labelLarge)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DesignSystem.Spacing.md)
                                    .background(DesignSystem.Colors.glassBackground)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                            .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
                                    )
                            }
                            .accessibilityLabel("View career statistics")
                            
                            Button {
                                onStartNew()
                            } label: {
                                Label("Start New Match", systemImage: "plus.circle.fill")
                                    .font(DesignSystem.Typography.labelLarge)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DesignSystem.Spacing.md)
                                    .background(DesignSystem.Colors.mintAccent)
                                    .foregroundStyle(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                            }
                            .accessibilityLabel("Start a new match")
                        }
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.bottom, DesignSystem.Spacing.xl)
                    }
                }
            }

                // Prominent dismiss, always visible in the top-right corner.
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                        .padding(16)
                }
                .accessibilityLabel("Dismiss results and return to Score")
            }
        }
    }
    
    private var matchDetailsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("MATCH DETAILS")
                .font(DesignSystem.Typography.captionSmall)
                .bold()
                .tracking(2)
                .foregroundStyle(DesignSystem.Colors.gray500)
            
            DetailRow(label: "Format", value: match.format)
            DetailRow(label: "Duration", value: match.formattedElapsedTime)
            DetailRow(label: "Location", value: match.location.isEmpty ? "Not specified" : match.location)
            DetailRow(label: "Date", value: match.date.formatted(date: .abbreviated, time: .shortened))
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.courtMid)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                .stroke(DesignSystem.Colors.glassBorder, lineWidth: 0.5)
        )
        .padding(.horizontal, DesignSystem.Layout.screenPadding)
    }
    
    private var statsSummaryCard: some View {
        let p1Events = match.pointEvents.filter { $0.player == match.playerOne }
        let p2Events = match.pointEvents.filter { $0.player == match.playerTwo }
        
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("MATCH STATS")
                .font(DesignSystem.Typography.captionSmall)
                .bold()
                .tracking(2)
                .foregroundStyle(DesignSystem.Colors.gray500)
            
            HStack(spacing: DesignSystem.Spacing.xl) {
                PlayerStatColumn(
                    name: match.playerOne.name,
                    color: DesignSystem.Colors.mintAccent,
                    aces: count(.ace, in: p1Events),
                    winners: count(.winner, in: p1Events) + count(.serveWinner, in: p1Events) + count(.returnWinner, in: p1Events),
                    unforcedErrors: count(.unforcedError, in: p1Events),
                    doubleFaults: count(.doubleFault, in: p1Events)
                )
                
                Divider()
                    .frame(height: 80)
                    .background(DesignSystem.Colors.glassBorder)
                
                PlayerStatColumn(
                    name: match.playerTwo.name,
                    color: DesignSystem.Colors.orangeAccent,
                    aces: count(.ace, in: p2Events),
                    winners: count(.winner, in: p2Events) + count(.serveWinner, in: p2Events) + count(.returnWinner, in: p2Events),
                    unforcedErrors: count(.unforcedError, in: p2Events),
                    doubleFaults: count(.doubleFault, in: p2Events)
                )
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.courtMid)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                .stroke(DesignSystem.Colors.glassBorder, lineWidth: 0.5)
        )
        .padding(.horizontal, DesignSystem.Layout.screenPadding)
    }
    
    private func count(_ outcome: PointOutcome, in events: [PointEvent]) -> Int {
        events.filter { $0.outcome == outcome }.count
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundStyle(DesignSystem.Colors.gray500)
            Spacer()
            Text(value)
                .font(DesignSystem.Typography.bodySmall)
                .bold()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

struct PlayerStatColumn: View {
    let name: String
    let color: Color
    let aces: Int
    let winners: Int
    let unforcedErrors: Int
    let doubleFaults: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(name.uppercased())
                .font(DesignSystem.Typography.captionSmall)
                .bold()
                .tracking(1)
                .foregroundStyle(color)
            
            StatRow(label: "Aces", value: aces, color: DesignSystem.Colors.warning)
            StatRow(label: "Winners", value: winners, color: DesignSystem.Colors.success)
            StatRow(label: "Unforced", value: unforcedErrors, color: DesignSystem.Colors.error)
            StatRow(label: "Dbl Faults", value: doubleFaults, color: DesignSystem.Colors.warning)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatRow: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.gray500)
            Spacer()
            Text("\(value)")
                .font(DesignSystem.Typography.captionMedium)
                .bold()
                .foregroundStyle(color)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    MatchResultsView(match: PreviewData.sampleMatch, onStartNew: {}, onDismiss: {})
}

private enum PreviewData {
    static var sampleMatch: Match {
        let p1 = Player(name: "Player 1")
        let p2 = Player(name: "Player 2")
        let match = Match(playerOne: p1, playerTwo: p2, format: "Best of 3 • Set to 6 • Tie-break to 7 • Advantage", location: "Center Court", setLength: 6, tieBreakLength: 7)
        match.winnerName = "Player 1"
        match.setScores = "6-4, 6-3"
        match.p1Sets = 2
        match.p2Sets = 0
        match.isCompleted = true
        return match
    }
}