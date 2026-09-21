import SwiftUI
import SwiftData
import Charts

struct PlayerProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let player: Player
    let matches: [Match]
    
    private var playerMatches: [Match] { matches.filter { $0.playerOne == player || $0.playerTwo == player } }
    private var totalWins: Int { playerMatches.filter { $0.winnerName == player.name }.count }
    private var winRate: Double { playerMatches.isEmpty ? 0 : (Double(totalWins) / Double(playerMatches.count)) * 100 }
    private var allPoints: [PointEvent] { playerMatches.flatMap { $0.pointEvents }.filter { $0.player == player } }
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.courtDark.ignoresSafeArea()
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    headerSection
                    dnaSection
                    historySection
                    
                    Button(role: .destructive) {
                        modelContext.delete(player)
                        dismiss()
                    } label: {
                        Label("Delete Player Profile", systemImage: "trash")
                            .font(DesignSystem.Typography.labelMedium)
                            .bold()
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(DesignSystem.Colors.error)
                    }
                    .buttonStyle(SecondaryButtonStyle(color: DesignSystem.Colors.error))
                    .padding(.top, DesignSystem.Spacing.lg)
                }
                .padding(.vertical, DesignSystem.Spacing.lg)
                .padding(.horizontal, DesignSystem.Layout.screenPadding)
            }
        }
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("CAREER ANALYTICS")
                    .font(DesignSystem.Typography.captionSmall)
                    .bold()
                    .tracking(3)
                    .foregroundStyle(DesignSystem.Colors.mintAccent)
                Text(player.name)
                    .font(DesignSystem.Typography.displayMedium)
                    .bold()
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            HStack(spacing: DesignSystem.Spacing.md) {
                statItem(label: "MATCHES", value: "\(playerMatches.count)")
                statItem(label: "WINS", value: "\(totalWins)")
                statItem(label: "WIN RATE", value: String(format: "%.1f%%", winRate))
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.courtMid)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                    .stroke(DesignSystem.Colors.mintAccent.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var dnaSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("POINT DNA")
                .font(DesignSystem.Typography.captionSmall)
                .bold()
                .tracking(2)
                .foregroundStyle(DesignSystem.Colors.gray500)
            
            Chart {
                BarMark(x: .value("Type", "Aces"), y: .value("Count", count(for: .ace)))
                    .foregroundStyle(DesignSystem.Colors.warning.gradient)
                BarMark(x: .value("Type", "Winners"), y: .value("Count", events(for: .winner).count))
                    .foregroundStyle(DesignSystem.Colors.success.gradient)
                BarMark(x: .value("Type", "Forced E"), y: .value("Count", events(for: .forcedError).count))
                    .foregroundStyle(DesignSystem.Colors.info.gradient)
                BarMark(x: .value("Type", "Unforced E"), y: .value("Count", events(for: .unforcedError).count))
                    .foregroundStyle(DesignSystem.Colors.error.gradient)
            }
            .frame(height: 180)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundStyle(DesignSystem.Colors.gray500)
                }
            }
            
            Text("Yellow: Aces  |  Green: Winners  |  Blue: Forced  |  Red: Unforced")
                .font(DesignSystem.Typography.captionSmall)
                .foregroundStyle(DesignSystem.Colors.gray500)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
        )
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("MATCH HISTORY")
                .font(DesignSystem.Typography.captionSmall)
                .bold()
                .tracking(2)
                .foregroundStyle(DesignSystem.Colors.gray500)
            
            ForEach(playerMatches.sorted(by: { $0.date > $1.date })) { match in
                HStack(spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("\(match.playerOne.name) vs \(match.playerTwo.name)")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundStyle(.white)
                        Text(match.setScores)
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                    }
                    Spacer()
                    Text(match.winnerName == player.name ? "WON" : "LOST")
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xxxs)
                        .background((match.winnerName == player.name ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.error).opacity(0.2))
                        .foregroundStyle(match.winnerName == player.name ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.error)
                        .clipShape(Capsule())
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.courtMid)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            }
        }
    }
    
    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.xxxs) {
            Text(value)
                .font(DesignSystem.Typography.headlineLarge)
                .bold()
                .foregroundStyle(.white)
            Text(label)
                .font(DesignSystem.Typography.captionSmall)
                .bold()
                .foregroundStyle(DesignSystem.Colors.gray500)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func count(for outcome: PointOutcome) -> Int { allPoints.filter { $0.outcome == outcome }.count }
    private func events(for outcome: PointOutcome) -> [PointEvent] { allPoints.filter { $0.outcome == outcome } }
}