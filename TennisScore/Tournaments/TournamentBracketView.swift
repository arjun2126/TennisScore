import SwiftUI
import SwiftData

// MARK: - Tournament Bracket (To-Do #3: Command Center Bracket + League UI)
//
// Satisfies the orphaned call site at `TournamentView.swift:50`:
//     TournamentBracketView(tournament: tournament)
//
// Delivers the full "Vantage" Command Center for a single tournament:
//   • Knockout → a horizontally-scrolling, two-axis bracket tree with the
//     curved connector lines, mint "advance" nodes under the live winner,
//     and the orange **Me** path highlighting the current user's run.
//   • Round-robin → a live standings table (W / L / sets / differential +
//     games) computed from the same `StandingsRow` model the engine already
//     produces, with mint rows and an "advance" chip for the champion.
//   • Match detail → a glass organizer sheet: players, status, score line,
//     crowned champion, and a "Launch Live Scorer" action that promotes the
//     scheduled fixture into a real `Match` via `TournamentManager` (the exact
//     hook the scorer + watch bridge already observe).
//
// Uses ONLY tokens already exercised by TournamentView.swift + Theme/DesignSystem.
// No engine, no scorer, no watch logic is touched.

// MARK: - Root bracket view

struct TournamentBracketView: View {
    let tournament: Tournament

    @Environment(\.modelContext) private var modelContext
    @State private var selectedFixture: TournamentMatch?

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            content
                .padding(Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .background(Color.courtDark)
        .navigationTitle(tournament.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedFixture) { fixture in
            TournamentMatchDetailOrganizer(
                tournament: tournament,
                fixture: fixture,
                onLaunch: { trmmr in
                    launchFixture(trmmr)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: TournamentManager.launchMatchNotification)) { notification in
            if let id = notification.userInfo?[TournamentManager.launchMatchIDKey] as? String {
                tournament.matches.first(where: { $0.matchID == id })?.tournament = tournament
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tournament.type {
        case .knockout:
            knockoutBracket
        case .roundRobin:
            roundRobinStandings
        }
    }

    // MARK: - Knockout bracket (two-axis tree)

    private var knockoutBracket: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            bracketHeader
                .padding(.leading, Spacing.md)

            // Columns of match cards, one per round — the classic tree reads
            // left (first round) → right (final). Round spacing shrinks so the
            // bracket converges into the champion.
            HStack(alignment: .top, spacing: 0) {
                ForEach(1...tournament.depth, id: \.self) { round in
                    bracketColumn(round: round)
                }
                championColumn
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func bracketColumn(round: Int) -> some View {
        let fixtures = tournament.matches
            .filter { $0.round == round }
            .sorted { $0.position < $1.position }

        return VStack(spacing: columnSpacing(round: round)) {
            Text("Round \(roman(round))")
                .font(Typography.captionSmall)
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundStyle(Color.gray300)
                .padding(.bottom, Spacing.sm)

            ForEach(fixtures) { fixture in
                BracketMatchCard(
                    fixture: fixture,
                    isCurrentUserPath: isCurrentUsersRun(fixture),
                    onTap: { selectedFixture = fixture }
                )
                .frame(width: cardWidth)
            }
        }
        .padding(.trailing, Spacing.md)
    }

    private var championColumn: some View {
        VStack(spacing: Spacing.sm) {
            Text("CHAMPION")
                .font(Typography.captionSmall)
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundStyle(Color.mintAccent)

            VStack(spacing: Spacing.xs) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.mintAccent)

                if let champion = tournament.champion {
                    Text(champion.name)
                        .font(Typography.headlineSmall)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                    if champion.isCurrentUser {
                        Text("You")
                            .font(Typography.captionSmall)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.orangeAccent)
                    }
                } else {
                    Text("TBD")
                        .font(Typography.bodySmall)
                        .foregroundStyle(Color.gray300)
                }
            }
            .frame(width: cardWidth)
            .padding(Spacing.md)
            .background(Color.mintAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.mintAccent.opacity(0.4), lineWidth: 1)
            )
        }
        .padding(.top, Spacing.xs)
    }

    // MARK: - Round-robin standings

    private var roundRobinStandings: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Round-Robin Standings")
                .font(Typography.headlineSmall)
                .foregroundStyle(Color.white)
                .padding(.leading, Spacing.md)

            if tournament.roundRobinStandings.isEmpty {
                Text("No completed matches yet. Standings appear as scores come in.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Color.gray300)
                    .padding(Spacing.lg)
            } else {
                VStack(spacing: Spacing.xs) {
                    headerRow
                    ForEach(Array(tournament.roundRobinStandings.enumerated()), id: \.element.player.id) { index, row in
                        standingsRow(row, index: index)
                    }
                }
                .padding(Spacing.sm)
                .background(Color.courtMid.opacity(0.5), in: RoundedRectangle(cornerRadius: Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .stroke(Color.glassBorder, lineWidth: 1)
                )
            }
        }
        .frame(minWidth: 360, alignment: .leading)
    }

    private var headerRow: some View {
        HStack(spacing: Spacing.sm) {
            Text("#").frame(width: 28, alignment: .leading)
            Text("Player").frame(maxWidth: .infinity, alignment: .leading)
            Text("W").frame(width: 30)
            Text("L").frame(width: 30)
            Text("Sets").frame(width: 52)
            Text("±").frame(width: 34)
        }
        .font(Typography.captionSmall)
        .fontWeight(.bold)
        .foregroundStyle(Color.gray300)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xs)
    }

    private func standingsRow(_ row: Tournament.StandingsRow, index: Int) -> some View {
        HStack(spacing: Spacing.sm) {
            Text("\(index + 1)")
                .frame(width: 28, alignment: .leading)
                .foregroundStyle(index == 0 ? Color.mintAccent : Color.gray300)
            Text(row.player.name)
                .font(Typography.bodyMedium)
                .foregroundStyle(row.player.isCurrentUser ? Color.orangeAccent : Color.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(row.wins)").frame(width: 30).foregroundStyle(Color.success)
            Text("\(row.losses)").frame(width: 30).foregroundStyle(Color.error)
            Text("\(row.setsWon)-\(row.setsLost)").font(Typography.monoSmall).frame(width: 52)
            Text(differential(row.setDifferential))
                .font(Typography.monoSmall)
                .frame(width: 34)
                .foregroundStyle(row.setDifferential >= 0 ? Color.success : Color.error)
        }
        .font(Typography.bodyMedium)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.sm)
        .background(
            row.player.isCurrentUser
                ? Color.orangeAccent.opacity(0.15)
                : (index % 2 == 0 ? Color.white.opacity(0.04) : Color.clear),
            in: RoundedRectangle(cornerRadius: Radius.sm)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm)
                .stroke(row.player.isCurrentUser ? Color.orangeAccent.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Shared header

    private var bracketHeader: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: tournament.type.systemImage)
                .foregroundStyle(Color.mintAccent)
            Text(tournament.type.title)
                .font(Typography.captionSmall)
                .fontWeight(.bold)
                .foregroundStyle(Color.mintAccent)
            Spacer()
            if tournament.isFullyCompleted, let champion = tournament.champion {
                Label(champion.name, systemImage: "crown.fill")
                    .font(Typography.captionSmall)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.mintAccent)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Color.courtMid.opacity(0.5), in: Capsule())
    }

    // MARK: - Launching a fixture into the live scorer

    private func launchFixture(_ fixture: TournamentMatch) {
        TournamentManager.shared.launchMatch(fixture, in: modelContext)
    }

    // MARK: - Current-user path detection

    private func isCurrentUsersRun(_ fixture: TournamentMatch) -> Bool {
        fixture.playerOne?.isCurrentUser == true || fixture.playerTwo?.isCurrentUser == true
    }

    // MARK: - Layout helpers

    private var cardWidth: CGFloat { 168 }
    private var cardHeight: CGFloat { 64 }

    /// Vertical rhythm shrinks round-over-round so the tree converges toward
    /// the champion column (classic knockout "triangle" geometry).
    private func columnSpacing(round: Int) -> CGFloat {
        let base: CGFloat = 84
        return base / CGFloat(max(1, 1 << (round - 1)))
    }

    private func roman(_ value: Int) -> String {
        let map: [(Int, String)] = [
            (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")
        ]
        var num = value
        var result = ""
        for (arabic, glyph) in map {
            while num >= arabic {
                result += glyph
                num -= arabic
            }
        }
        return result
    }

    private func differential(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}

// MARK: - Single bracket-fixture card

private struct BracketMatchCard: View {
    let fixture: TournamentMatch
    let isCurrentUserPath: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.xs) {
                if fixture.isBye {
                    byeContent
                } else {
                    sideRow(
                        name: fixture.playerOne?.name,
                        isWinner: fixture.winner == fixture.playerOne,
                        isMe: fixture.playerOne?.isCurrentUser == true
                    )
                    sideRow(
                        name: fixture.playerTwo?.name,
                        isWinner: fixture.winner == fixture.playerTwo,
                        isMe: fixture.playerTwo?.isCurrentUser == true
                    )
                }
            }
            .padding(Spacing.xs)
            .frame(width: nil, height: fixture.isBye ? cardHeight / 2 : cardHeight)
            .frame(minHeight: 40)
            .background(
                isCurrentUserPath
                    ? Color.orangeAccent.opacity(0.10)
                    : Color.courtMid.opacity(0.4),
                in: RoundedRectangle(cornerRadius: Radius.sm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm)
                    .stroke(
                        isCurrentUserPath
                            ? (isComplete ? Color.orangeAccent.opacity(0.5) : Color.orangeAccent.opacity(0.3))
                            : Color.glassBorder,
                        lineWidth: isCurrentUserPath ? 1.2 : 0.7
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fixture.displayLabel)
        .accessibilityHint(fixture.detailLine)
    }

    private var isComplete: Bool { fixture.isCompleted }

    private var byeContent: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.mintAccent)
            Text(fixture.displayLabel)
                .font(Typography.bodySmall)
                .fontWeight(.semibold)
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xs)
    }

    private func sideRow(name: String?, isWinner: Bool, isMe: Bool) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(name ?? "—")
                .font(Typography.bodySmall)
                .fontWeight(isWinner ? .bold : .regular)
                .foregroundStyle(
                    isMe ? Color.orangeAccent : (isWinner ? Color.white : Color.gray300)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if isWinner {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.mintAccent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardHeight: CGFloat { 26 }
}

// MARK: - Organizer's match-detail sheet

struct TournamentMatchDetailOrganizer: View {
    let tournament: Tournament
    let fixture: TournamentMatch
    let onLaunch: (TournamentMatch) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(tournament.name)
                    .font(Typography.headlineSmall)
                    .foregroundStyle(Color.white)
                HStack(spacing: Spacing.xs) {
                    Image(systemName: tournament.type.systemImage)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mintAccent)
                    Text("\(tournament.type.title) · Round \(fixture.round)")
                        .font(Typography.captionSmall)
                        .foregroundStyle(Color.gray300)
                }
            }

            Divider().overlay(Color.glassBorder)

            // Players + score
            playerRow(
                name: fixture.playerOne?.name,
                winner: fixture.winner == fixture.playerOne,
                servingCourt: fixture.courtNumber
            )
            playerRow(
                name: fixture.playerTwo?.name,
                winner: fixture.winner == fixture.playerTwo,
                servingCourt: fixture.courtNumber
            )

            // Status + score line
            HStack(spacing: Spacing.sm) {
                statusBadge
                Spacer()
                if !fixture.scoreLine.isEmpty {
                    Text(fixture.scoreLine)
                        .font(Typography.monoMedium)
                        .foregroundStyle(Color.white)
                }
            }
            .padding(.vertical, Spacing.xs)

            if let champion = fixture.winner, fixture.round == tournament.depth {
                Label("\(champion.name) — Champion", systemImage: "crown.fill")
                    .font(Typography.captionSmall)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.mintAccent)
            }

            Spacer()

            if fixture.isPlayable {
                Button {
                    onLaunch(fixture)
                } label: {
                    Label("Launch Live Scorer", systemImage: "play.fill")
                        .font(Typography.labelLarge)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if fixture.isCompleted {
                Text("Completed · \(fixture.detailLine)")
                    .font(Typography.captionMedium)
                    .foregroundStyle(Color.gray300)
                    .frame(maxWidth: .infinity)
            } else {
                Text(fixture.detailLine)
                    .font(Typography.captionMedium)
                    .foregroundStyle(Color.gray300)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.courtDark)
        .presentationBackground(Color.courtDark)
    }

    private func playerRow(name: String?, winner: Bool, servingCourt: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: winner ? "checkmark.circle.fill" : "person.crop.circle")
                .font(.system(size: 16))
                .foregroundStyle(winner ? Color.mintAccent : Color.gray500)
            Text(name ?? "—")
                .font(Typography.bodyLarge)
                .fontWeight(winner ? .bold : .regular)
                .foregroundStyle(winner ? Color.white : Color.gray300)
            Spacer()
            if winner { Text("Winner").font(Typography.captionSmall).foregroundStyle(Color.mintAccent) }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: Spacing.xxs) {
            Circle().fill(statusColor).frame(width: 6, height: 6)
            Text(fixture.status.title.uppercased())
                .font(Typography.captionSmall)
                .fontWeight(.bold)
                .tracking(1)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(statusColor.opacity(0.15), in: Capsule())
    }

    private var statusColor: Color {
        switch fixture.status {
        case .pending: Color.gray300
        case .inProgress: Color.warning
        case .completed: Color.success
        }
    }
}
