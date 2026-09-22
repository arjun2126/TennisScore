import SwiftUI
import SwiftData
import Foundation

// MARK: - League Card

struct LeagueCard: View {
    let league: League

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "calendar")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.mintAccent)
                .frame(width: 40, height: 40)
                .background(Color.courtMid, in: RoundedRectangle(cornerRadius: Radius.sm))

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(league.name)
                    .font(Typography.headlineSmall)
                    .foregroundStyle(Color.white)
                HStack(spacing: Spacing.xs) {
                    Text("\(league.roster.count) players")
                        .font(Typography.captionSmall)
                        .foregroundStyle(Color.gray300)
                    if league.weeks > 0 {
                        Text("•")
                            .foregroundStyle(Color.gray500)
                        Text("\(league.weeks) week\(league.weeks == 1 ? "" : "s")")
                            .font(Typography.captionSmall)
                            .foregroundStyle(Color.gray300)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.gray500)
        }
        .padding(Spacing.md)
        .background(Color.courtMid.opacity(0.6), in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Color.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - League Detail (schedule)

struct LeagueDetailView: View {
    let league: League

    @State private var scoringMatch: LeagueMatch?
    @State private var shareURL: URL?
    @State private var isPreparingShare = false
    @State private var showingShare = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                header
                standings
                schedule
            }
            .padding(Spacing.md)
        }
        .background(Color.courtDark)
        .navigationTitle(league.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    prepareShare()
                } label: {
                    Image(systemName: isPreparingShare ? "hourglass" : "square.and.arrow.up")
                        .foregroundStyle(Color.mintAccent)
                }
                .disabled(isPreparingShare)
            }
        }
        .sheet(item: $scoringMatch) { match in
            LeagueScoreSheet(match: match)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingShare) {
            if let shareURL {
                ShareSheet(activityItems: [shareURL])
            }
        }
    }

    private func prepareShare() {
        guard !isPreparingShare else { return }
        isPreparingShare = true
        Task {
            do {
                let url = try await ExportManager.prepareShare(for: league)
                await MainActor.run {
                    self.shareURL = url
                    self.isPreparingShare = false
                    self.showingShare = true
                }
            } catch {
                await MainActor.run { self.isPreparingShare = false }
            }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "calendar")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.mintAccent)
                .frame(width: 40, height: 40)
                .background(Color.courtMid, in: RoundedRectangle(cornerRadius: Radius.sm))

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(league.name)
                    .font(Typography.headlineSmall)
                    .foregroundStyle(Color.white)
                Text("\(league.roster.count) players • \(league.weeks) week\(league.weeks == 1 ? "" : "s")")
                    .font(Typography.captionSmall)
                    .foregroundStyle(Color.gray300)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.courtMid.opacity(0.6), in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Color.glassBorder, lineWidth: 1)
        )
    }

    private var schedule: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if league.matches.isEmpty {
                Text("No schedule yet — recreate the league to generate its weekly fixtures.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Color.gray300)
            } else {
                ForEach(1...league.weeks, id: \.self) { week in
                    weekSection(week)
                }
            }
        }
    }

    private var standings: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Standings")
                .font(Typography.labelLarge)
                .foregroundStyle(Color.mintAccent)
            if league.completedMatches.isEmpty {
                Text("No results yet — standings appear once matches are scored.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Color.gray300)
            } else {
                standingsHeader
                ForEach(Array(league.standings.enumerated()), id: \.element.id) { index, row in
                    StandingsRowView(rank: index + 1, row: row, isLeader: index == 0)
                }
            }
        }
    }

    private var standingsHeader: some View {
        HStack(spacing: Spacing.sm) {
            Text("#")
                .frame(width: 22, alignment: .leading)
            Text("Player")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("W‑L")
                .frame(width: 44, alignment: .trailing)
            Text("Pts")
                .frame(width: 30, alignment: .trailing)
            Text("Sets")
                .frame(width: 40, alignment: .trailing)
        }
        .font(Typography.captionSmall)
        .foregroundStyle(Color.gray500)
        .padding(.horizontal, Spacing.sm)
    }

    @ViewBuilder
    private func weekSection(_ week: Int) -> some View {
        let matches = league.matches.filter { $0.week == week }.sorted { $0.position < $1.position }
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Week \(week)")
                .font(Typography.labelLarge)
                .foregroundStyle(Color.mintAccent)
            ForEach(matches) { match in
                Button {
                    scoringMatch = match
                } label: {
                    LeagueMatchRow(match: match)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Score Entry Sheet

struct LeagueScoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let match: LeagueMatch

    @State private var winnerIsP1 = true
    @State private var setScoresText = ""
    @State private var showValidationError = false

    private var p1Name: String { match.playerOne?.name ?? "—" }
    private var p2Name: String { match.playerTwo?.name ?? "—" }

    /// Parses the comma-separated score line as (winnerSets, loserSets).
    /// Matches the parsing in `LeagueMatch.setsWonBy(_:)`.
    private var parsed: (winnerSets: Int, loserSets: Int)? {
        let parts = setScoresText.split(separator: ",")
        guard !parts.isEmpty else { return nil }
        var winnerSets = 0
        var loserSets = 0
        for part in parts {
            let scores = part.trimmingCharacters(in: .whitespaces).split(separator: "-")
            guard scores.count == 2,
                  let a = Int(scores[0]), let b = Int(scores[1]),
                  a >= 0, b >= 0, a != b else { return nil }
            if a > b { winnerSets += 1 } else { loserSets += 1 }
        }
        return (winnerSets, loserSets)
    }

    private var isScoreValid: Bool {
        guard let p = parsed else { return false }
        return p.winnerSets > p.loserSets
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Matchup") {
                    Text(match.displayLabel)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Color.white)
                }
                Section("Winner") {
                    Picker("Winner", selection: $winnerIsP1) {
                        Text(p1Name).tag(true)
                        Text(p2Name).tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Set scores") {
                    TextField("6-4, 6-2", text: $setScoresText)
                        .keyboardType(.numbersAndPunctuation)
                    Text("Enter winner‑first scores per set, comma separated.")
                        .font(Typography.captionSmall)
                        .foregroundStyle(Color.gray300)
                    if showValidationError {
                        Text("Use a valid score line like \"6-4, 6-2\" with the winner leading each set.")
                            .font(Typography.captionSmall)
                            .foregroundStyle(Color.orangeAccent)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.courtDark)
            .navigationTitle("Record Result")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isScoreValid)
                }
            }
        }
        .tint(Color.mintAccent)
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard let score = parsed, isScoreValid else {
            showValidationError = true
            return
        }
        _ = score
        match.winner = winnerIsP1 ? match.playerOne : match.playerTwo
        match.setScores = setScoresText.trimmingCharacters(in: .whitespaces)
        match.statusRaw = LeagueMatchStatus.completed.rawValue
        try? modelContext.save()
        dismiss()
    }
}

private struct StandingsRowView: View {
    let rank: Int
    let row: League.StandingsRow
    let isLeader: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Group {
                if isLeader {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(Color.orangeAccent)
                } else {
                    Text("\(rank)")
                }
            }
            .font(Typography.captionSmall)
            .frame(width: 22, alignment: .leading)
            .foregroundStyle(isLeader ? Color.orangeAccent : Color.gray300)

            Text(row.player.name)
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            Text("\(row.wins)-\(row.losses)")
                .font(Typography.captionSmall)
                .foregroundStyle(Color.gray300)
                .frame(width: 44, alignment: .trailing)
            Text("\(row.points)")
                .font(Typography.captionSmall)
                .foregroundStyle(Color.mintAccent)
                .frame(width: 30, alignment: .trailing)
            Text("\(row.setsWon)-\(row.setsLost)")
                .font(Typography.captionSmall)
                .foregroundStyle(Color.gray300)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(Spacing.sm)
        .background(Color.courtMid.opacity(0.6), in: RoundedRectangle(cornerRadius: Radius.sm))
    }
}

private struct LeagueMatchRow: View {
    let match: LeagueMatch

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(match.displayLabel)
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.white)
            Spacer()
            Text(match.status.title)
                .font(Typography.captionSmall)
                .foregroundStyle(match.isCompleted ? Color.success : Color.gray300)
        }
        .padding(Spacing.sm)
        .background(Color.courtMid.opacity(0.6), in: RoundedRectangle(cornerRadius: Radius.sm))
    }
}

// MARK: - Create League Sheet

struct CreateLeagueSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Player.name) private var players: [Player]

    @State private var name = ""
    @State private var selectedPlayers: Set<Player.ID> = []

    let onCreate: (String, [Player]) -> Void

    private var selected: [Player] {
        players.filter { selectedPlayers.contains($0.id) }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("League Name", text: $name)
                }

                Section("Roster (\(selected.count))") {
                    ForEach(players) { player in
                        RosterEntryRow(player: player, isSelected: selectedPlayers.contains(player.id)) { isOn in
                            if isOn {
                                selectedPlayers.insert(player.id)
                            } else {
                                selectedPlayers.remove(player.id)
                            }
                        }
                    }
                    if players.isEmpty {
                        Text("Add players in the Rivals tab first.")
                            .font(Typography.captionSmall)
                            .foregroundStyle(Color.gray300)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.courtDark)
            .navigationTitle("New League")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name, selected)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selected.count < 2)
                }
            }
        }
        .tint(Color.mintAccent)
        .preferredColorScheme(.dark)
    }
}

private struct RosterEntryRow: View {
    let player: Player
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? Color.mintAccent : Color.gray500)
            Text(player.name)
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.white)
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? Color.mintAccent : Color.gray300)
                .contentShape(Rectangle())
                .onTapGesture { onToggle(!isSelected) }
        }
        .contentShape(Rectangle())
    }
}