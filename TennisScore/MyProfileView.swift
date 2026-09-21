import SwiftUI
import SwiftData

/// Personal Performance Journal dashboard for the current user ("Me").
struct MyProfileView: View {
    @Query(sort: \Player.name) private var players: [Player]
    @Query private var matches: [Match]
    
    private var me: Player? {
        players.first(where: { $0.isCurrentUser })
    }
    
    private var myMatches: [Match] {
        guard let me else { return [] }
        return matches.filter { $0.isCompleted && ($0.playerOne == me || $0.playerTwo == me) }
    }
    
    private var wins: Int {
        guard let me else { return 0 }
        return myMatches.filter { $0.winnerName == me.name }.count
    }
    
    private var winRate: Double {
        myMatches.isEmpty ? 0 : (Double(wins) / Double(myMatches.count)) * 100
    }
    
    private var sensedMatches: [Match] {
        myMatches.filter { $0.avgHeartRate > 0 }
    }
    
    private var averageHeartRate: Double {
        guard !sensedMatches.isEmpty else { return 0 }
        return sensedMatches.map(\.avgHeartRate).reduce(0, +) / Double(sensedMatches.count)
    }
    
    private var totalCalories: Double {
        myMatches.map(\.totalCalories).reduce(0, +)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.courtDark.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        if let me {
                            profileHeader(me: me)
                            performanceCard
                            biometricsCard
                        } else {
                            setupPromptCard
                        }
                    }
                    .padding(.horizontal, DesignSystem.Layout.screenPadding)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("My Profile")
        }
    }
    
    private var setupPromptCard: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(DesignSystem.Colors.mintAccent)
                .accessibilityHidden(true)
            Text("Set Up Your Profile")
                .font(DesignSystem.Typography.headlineMedium)
                .bold()
                .foregroundStyle(.white)
            Text("Go to the Players tab and tap ☆ on your name. Your wins, rivals, and biometrics will live here.")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(DesignSystem.Colors.gray500)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.xl)
        .background(DesignSystem.Colors.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Set up your profile in the Players tab")
    }
    
    private func profileHeader(me: Player) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(me.name)
                        .font(DesignSystem.Typography.headlineMedium)
                        .bold()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("YOU")
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 1)
                        .background(DesignSystem.Colors.mintAccent.opacity(0.25))
                        .foregroundStyle(DesignSystem.Colors.mintAccent)
                        .clipShape(Capsule())
                }
                Text("\(myMatches.count) Matches • \(wins) Wins")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.gray500)
                    .lineLimit(1)
            }
            Spacer(minLength: DesignSystem.Spacing.xs)
            VStack(spacing: 0) {
                Text("\(Int(winRate))%")
                    .font(DesignSystem.Typography.displaySmall)
                    .bold()
                    .foregroundStyle(DesignSystem.Colors.mintAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("WIN RATE")
                    .font(DesignSystem.Typography.captionSmall)
                    .bold()
                    .foregroundStyle(DesignSystem.Colors.gray500)
                    .lineLimit(1)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.courtMid)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                .stroke(DesignSystem.Colors.mintAccent.opacity(0.4), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(me.name), \(myMatches.count) matches, \(wins) wins, \(Int(winRate)) percent win rate")
    }
    
    private var performanceCard: some View {
        statCard(title: "PERFORMANCE", rows: [
            ("Total Matches", "\(myMatches.count)"),
            ("Total Wins", "\(wins)"),
            ("Win Rate", "\(Int(winRate))%")
        ])
    }
    
    private var biometricsCard: some View {
        statCard(title: "BIOMETRICS", rows: [
            ("Avg Match Heart Rate", sensedMatches.isEmpty ? "—" : "\(Int(averageHeartRate)) BPM"),
            ("Total Calories Burned", totalCalories <= 0 ? "—" : "\(Int(totalCalories)) kcal"),
            ("Sensed Matches", "\(sensedMatches.count)")
        ])
    }
    
    private func statCard(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(DesignSystem.Typography.captionSmall)
                .bold()
                .tracking(2)
                .foregroundStyle(DesignSystem.Colors.gray500)
            ForEach(rows, id: \.0) { label, value in
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
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.courtMid)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
        )
    }
}
