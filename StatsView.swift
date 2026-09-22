import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Player.name) private var players: [Player]
    @Query private var matches: [Match]
    @State private var searchText = ""
    
    var filteredPlayers: [Player] {
        if searchText.isEmpty { return players }
        return players.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var recentMatches: [Match] {
        matches.filter { $0.isCompleted }.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.courtDark.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        GlobalStatsHeader(matches: matches, playersCount: players.count)
                        
                        // Search Field
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(DesignSystem.Colors.gray500)
                                .accessibilityHidden(true)
                            TextField("Search Players...", text: $searchText)
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundStyle(.white)
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.courtMid)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                        .padding(.horizontal, DesignSystem.Layout.screenPadding)
                        .accessibilityLabel("Search players")
                        .accessibilityHint("Enter a player name to filter the list")
                        
                        // Section Header
                        Text("PLAYER PROFILES")
                            .font(DesignSystem.Typography.captionSmall)
                            .bold()
                            .tracking(2)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DesignSystem.Layout.screenPadding)
                        
                        // Player Cards
                        VStack(spacing: DesignSystem.Spacing.md) {
                            ForEach(filteredPlayers) { player in
                                NavigationLink(destination: PlayerProfileView(player: player, matches: matches)) {
                                    PlayerPerformanceCard(player: player, matches: matches)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, DesignSystem.Layout.screenPadding)
                        
                        // Section Header — History folded into Stats
                        Text("RECENT MATCHES")
                            .font(DesignSystem.Typography.captionSmall)
                            .bold()
                            .tracking(2)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DesignSystem.Layout.screenPadding)
                        
                        if recentMatches.isEmpty {
                            Text("Completed matches will appear here.")
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundStyle(DesignSystem.Colors.gray300)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, DesignSystem.Layout.screenPadding)
                        } else {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                ForEach(recentMatches) { match in
                                    recentMatchRow(match)
                                }
                            }
                            .padding(.horizontal, DesignSystem.Layout.screenPadding)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Performance")
        }
    }
    
    private func recentMatchRow(_ match: Match) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.md) {
                NavigationLink(destination: MatchDetailView(match: match)) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("\(match.playerOne.name) vs \(match.playerTwo.name)")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(match.setScores)
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundStyle(DesignSystem.Colors.mintAccent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxs) {
                    Text(match.winnerName)
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xxxs)
                        .background(DesignSystem.Colors.mintAccent.opacity(0.2))
                        .foregroundStyle(DesignSystem.Colors.mintAccent)
                        .clipShape(Capsule())
                    Text(match.date, format: .dateTime.day().month().year())
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundStyle(DesignSystem.Colors.gray500)
                }
            }
            HStack(spacing: DesignSystem.Spacing.xs) {
                PDFShareButton(match: match) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(DesignSystem.Typography.captionSmall)
                }
                .tint(DesignSystem.Colors.info)
                Button {
                    withAnimation(DesignSystem.Animation.springMedium) {
                        modelContext.delete(match)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(DesignSystem.Typography.captionSmall)
                }
                .tint(DesignSystem.Colors.error)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
        )
    }
}

struct GlobalStatsHeader: View {
    let matches: [Match]
    let playersCount: Int
    
    var completedMatches: Int {
        matches.filter { $0.isCompleted }.count
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            statBox(title: "TOTAL MATCHES", value: "\(completedMatches)", color: DesignSystem.Colors.mintAccent)
            statBox(title: "TOTAL PLAYERS", value: "\(playersCount)", color: DesignSystem.Colors.info)
        }
        .padding(.horizontal, DesignSystem.Layout.screenPadding)
    }
    
    private func statBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text(value)
                .font(DesignSystem.Typography.displaySmall)
                .bold()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(title)
                .font(DesignSystem.Typography.captionSmall)
                .bold()
                .tracking(1)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.courtMid)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
    }
}

struct PlayerPerformanceCard: View {
    let player: Player
    let matches: [Match]
    
    var body: some View {
        let playerMatches = matches.filter { $0.playerOne == player || $0.playerTwo == player }
        let wins = playerMatches.filter { $0.winnerName == player.name }.count
        let winRate = playerMatches.isEmpty ? 0 : (Double(wins) / Double(playerMatches.count)) * 100
        
        return HStack(spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(player.name)
                    .font(DesignSystem.Typography.headlineSmall)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(playerMatches.count) Matches")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.gray500)
                    .lineLimit(1)
            }
            Spacer(minLength: DesignSystem.Spacing.xs)
            HStack(spacing: DesignSystem.Spacing.sm) {
                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxxs) {
                    Text("\(wins)")
                        .font(DesignSystem.Typography.headlineMedium)
                        .bold()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("W")
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .foregroundStyle(DesignSystem.Colors.mintAccent)
                        .lineLimit(1)
                }
                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxxs) {
                    Text("\(Int(winRate))%")
                        .font(DesignSystem.Typography.headlineMedium)
                        .bold()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("WIN")
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .foregroundStyle(DesignSystem.Colors.mintAccent)
                        .lineLimit(1)
                }
            }
            Image(systemName: "chevron.right")
                .font(DesignSystem.Typography.captionSmall)
                .foregroundStyle(DesignSystem.Colors.gray300)
                .accessibilityHidden(true)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(player.name), \(playerMatches.count) matches, \(wins) wins, \(Int(winRate)) percent win rate")
        .accessibilityHint("Tap to view detailed profile")
        .accessibilityAddTraits(.isButton)
    }
}