import SwiftUI
import SwiftData

/// Personal Performance Journal dashboard for the current user ("Me").
/// Renders as a plain embeddable section (no tab, no NavigationStack) so it
/// can live inside the Settings tab.
struct MyProfileView: View {
    @Query(sort: \Player.name) private var players: [Player]
    @Query private var matches: [Match]
    @Query private var events: [Event]
    
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
        VStack(spacing: DesignSystem.Spacing.lg) {
            if let me {
                profileHeader(me: me)
                performanceCard
                biometricsCard
                ratingCard(me: me)
            } else {
                setupPromptCard
            }
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
            Text("Go to the Rivals tab and tap ☆ on your name. Your wins, rivals, and biometrics will live here.")
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

    // MARK: - Singles rating (Phase 6)

    private func ratingCard(me: Player) -> some View {
        let rating = me.singlesRating
        let band = me.ratingBand
        let history = ratedHistory(me)
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("SINGLES RATING")
                .font(DesignSystem.Typography.captionSmall)
                .bold()
                .tracking(2)
                .foregroundStyle(DesignSystem.Colors.gray500)
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.0f", rating.rating))
                    .font(DesignSystem.Typography.displaySmall)
                    .bold()
                    .foregroundStyle(.white)
                if rating.isProvisional {
                    Text("PROVISIONAL")
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 1)
                        .background(DesignSystem.Colors.warning.opacity(0.25))
                        .foregroundStyle(DesignSystem.Colors.warning)
                        .clipShape(Capsule())
                } else {
                    Text("RELIABILITY \(rating.confidence)")
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .foregroundStyle(DesignSystem.Colors.mintAccent)
                }
            }
            HStack {
                Text(band?.label ?? "Unrated")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundStyle(DesignSystem.Colors.gray500)
                Spacer()
                Text("\(rating.ratedGames) rated matches".uppercased())
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            }
            Toggle(isOn: Binding(
                get: { me.ratingPublic },
                set: { me.ratingPublic = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show rating on event pages")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundStyle(.white)
                    Text("Off by default — your rating stays private.")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundStyle(DesignSystem.Colors.gray500)
                }
            }
            .tint(DesignSystem.Colors.mintAccent)

            if !history.isEmpty {
                Text("RATED EVENT HISTORY")
                    .font(DesignSystem.Typography.captionSmall)
                    .bold()
                    .tracking(2)
                    .foregroundStyle(DesignSystem.Colors.gray500)
                    .padding(.top, DesignSystem.Spacing.xs)
                ForEach(history, id: \.id) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(entry.winner) def. \(entry.loser)")
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("\(entry.eventName) on \(entry.date.formatted(date: .abbreviated, time: .omitted))")
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundStyle(DesignSystem.Colors.gray500)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(entry.won ? "W" : "L")
                            .font(DesignSystem.Typography.labelMedium)
                            .bold()
                            .foregroundStyle(entry.won ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.error)
                    }
                }
            } else {
                Text("Win rated event matches to see your Glicko-2 singles rating move here.")
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.courtMid)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
        )
    }

    private func ratedHistory(_ me: Player) -> [(id: String, date: Date, eventName: String, winner: String, loser: String, won: Bool)] {
        let rows: [(date: Date, eventName: String, winner: String, loser: String, won: Bool)] = Array(events
            .filter { $0.ratingOn && me.ratingBandRaw == RatingsManager.ratingBand(for: $0).rawValue }
            .flatMap { event in
                event.matches
                    .filter { $0.status == .played && ($0.playerAName == me.name || $0.playerBName == me.name) }
                    .compactMap { match -> (date: Date, eventName: String, winner: String, loser: String, won: Bool)? in
                        guard let winner = match.winnerName else { return nil }
                        let loser = winner == match.playerAName ? match.playerBName : match.playerAName
                        return (
                            date: match.scheduledAt,
                            eventName: event.name,
                            winner: winner,
                            loser: loser,
                            won: winner == me.name
                        )
                    }
            }
            .sorted { $0.date > $1.date }
            .prefix(10))
        return Array(rows.enumerated()).map { index, row in
            (
                id: "\(index)-\(row.eventName)-\(row.date.timeIntervalSince1970)",
                date: row.date,
                eventName: row.eventName,
                winner: row.winner,
                loser: row.loser,
                won: row.won
            )
        }
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
