import SwiftUI

struct MatchDetailView: View {
    let match: Match
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.courtDark.ignoresSafeArea()
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Match Header
                    VStack(spacing: DesignSystem.Spacing.md) {
                        HStack(spacing: DesignSystem.Spacing.xl) {
                            VStack(spacing: DesignSystem.Spacing.xs) {
                                Text(match.playerOne.name)
                                    .font(DesignSystem.Typography.headlineSmall)
                                    .foregroundStyle(.white)
                                Text("\(match.p1Sets)")
                                    .font(DesignSystem.Typography.displayMedium)
                                    .bold()
                                    .foregroundStyle(DesignSystem.Colors.mintAccent)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Text("VS")
                                .font(DesignSystem.Typography.captionSmall)
                                .bold()
                                .foregroundStyle(DesignSystem.Colors.gray500)
                                .accessibilityHidden(true)
                            
                            VStack(spacing: DesignSystem.Spacing.xs) {
                                Text(match.playerTwo.name)
                                    .font(DesignSystem.Typography.headlineSmall)
                                    .foregroundStyle(.white)
                                Text("\(match.p2Sets)")
                                    .font(DesignSystem.Typography.displayMedium)
                                    .bold()
                                    .foregroundStyle(DesignSystem.Colors.orangeAccent)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .background(DesignSystem.Colors.glassBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                                .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(match.playerOne.name) \(match.p1Sets) sets, \(match.playerTwo.name) \(match.p2Sets) sets")
                        
                        Text(match.setScores)
                            .font(DesignSystem.Typography.scoreMedium)
                            .bold()
                            .foregroundStyle(.white)
                            .accessibilityLabel("Final score: \(match.setScores)")
                    }
                    .padding(.horizontal, DesignSystem.Layout.screenPadding)
                    
                    // Statistics
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("STATISTICS")
                            .font(DesignSystem.Typography.captionSmall)
                            .bold()
                            .tracking(2)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                        
                        statComparisonRow(label: "Aces", p1: count(for: .ace, player: match.playerOne), p2: count(for: .ace, player: match.playerTwo), color: DesignSystem.Colors.warning)
                        statComparisonRow(label: "Winners", p1: count(for: .winner, player: match.playerOne), p2: count(for: .winner, player: match.playerTwo), color: DesignSystem.Colors.success)
                        statComparisonRow(label: "Unforced Errors", p1: count(for: .unforcedError, player: match.playerOne), p2: count(for: .unforcedError, player: match.playerTwo), color: DesignSystem.Colors.error)
                        statComparisonRow(label: "Forced Errors", p1: count(for: .forcedError, player: match.playerOne), p2: count(for: .forcedError, player: match.playerTwo), color: DesignSystem.Colors.info)
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .background(DesignSystem.Colors.courtMid)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                            .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, DesignSystem.Layout.screenPadding)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Match statistics. \(match.playerOne.name): \(count(for: .ace, player: match.playerOne)) aces, \(count(for: .winner, player: match.playerOne)) winners, \(count(for: .unforcedError, player: match.playerOne)) unforced errors, \(count(for: .forcedError, player: match.playerOne)) forced errors. \(match.playerTwo.name): \(count(for: .ace, player: match.playerTwo)) aces, \(count(for: .winner, player: match.playerTwo)) winners, \(count(for: .unforcedError, player: match.playerTwo)) unforced errors, \(count(for: .forcedError, player: match.playerTwo)) forced errors.")
                    
                    // Match Notes
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("MATCH NOTES")
                            .font(DesignSystem.Typography.captionSmall)
                            .bold()
                            .tracking(2)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                        
                        let notes = match.pointEvents.filter { !$0.note.isEmpty }
                        if notes.isEmpty {
                            Text("No notes recorded")
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundStyle(DesignSystem.Colors.gray500)
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, DesignSystem.Spacing.lg)
                        } else {
                            ForEach(notes) { event in
                                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                                    Text("\(event.player.name.prefix(1))")
                                        .font(DesignSystem.Typography.labelMedium)
                                        .bold()
                                        .foregroundStyle(event.player == match.playerOne ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.orangeAccent)
                                        .frame(width: 20)
                                        .accessibilityLabel("\(event.player.name)")
                                    Text(event.note)
                                        .font(DesignSystem.Typography.bodySmall)
                                        .foregroundStyle(.white)
                                }
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                Divider().background(DesignSystem.Colors.glassBorder)
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .background(DesignSystem.Colors.glassBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                            .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, DesignSystem.Layout.screenPadding)
                }
                .padding(.vertical, DesignSystem.Spacing.lg)
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                PDFShareButton(match: match) {
                    Label("Share Match", systemImage: "square.and.arrow.up")
                }
                .accessibilityLabel("Share match summary as PDF")
            }
        }
    }
    
    private func count(for outcome: PointOutcome, player: Player) -> Int {
        match.pointEvents.filter { $0.player == player && $0.outcome == outcome }.count
    }
    
    private func statComparisonRow(label: String, p1: Int, p2: Int, color: Color) -> some View {
        let total = p1 + p2
        let p1Width = total == 0 ? 0.5 : Double(p1) / Double(total)
        return VStack(spacing: DesignSystem.Spacing.xs) {
            Text(label)
                .font(DesignSystem.Typography.captionMedium)
                .bold()
                .foregroundStyle(DesignSystem.Colors.gray700)
            HStack(spacing: 0) {
                ZStack(alignment: .trailing) {
                    Rectangle()
                        .fill(color.gradient)
                        .frame(width: max(2, CGFloat(p1Width * 280)), height: 12)
                    Text("\(p1)")
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .foregroundStyle(.white)
                        .padding(.trailing, DesignSystem.Spacing.xs)
                }
                Rectangle()
                    .fill(DesignSystem.Colors.glassBorder)
                    .frame(width: 4, height: 12)
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill((color == DesignSystem.Colors.warning ? DesignSystem.Colors.orangeAccent : color).gradient)
                        .frame(width: max(2, CGFloat((1 - p1Width) * 280)), height: 12)
                    Text("\(p2)")
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .foregroundStyle(.white)
                        .padding(.leading, DesignSystem.Spacing.xs)
                }
            }
            .frame(height: 12)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}