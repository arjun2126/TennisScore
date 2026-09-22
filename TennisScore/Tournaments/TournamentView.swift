import SwiftUI
import SwiftData
import Foundation

// MARK: - The Tournament Hub (Command Center)

/// The "Command Center" tab. Lists every saved tournament with live knockout /
/// round-robin status, surfaces past champions, and lets the player create a
/// new bracket. A Tournaments | Leagues segmented control also hosts the
/// season-long round-robin leagues and their weekly scoring. All scoring is
/// delegated to a real, tagged `Match` (launched through `TournamentManager`) so
/// the existing S‑G‑P live scorer + watch handshake are reused unchanged.
struct TournamentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tournament.dateCreated, order: .reverse) private var tournaments: [Tournament]
    @Query(sort: \League.dateCreated, order: .reverse) private var leagues: [League]
    @Query(sort: \Player.name) private var players: [Player]

    enum HubMode: String, CaseIterable, Identifiable {
        case tournaments
        case leagues

        var id: Self { self }

        var title: String {
            switch self {
            case .tournaments: "Tournaments"
            case .leagues: "Leagues"
            }
        }

        var newTitle: String {
            switch self {
            case .tournaments: "New Tournament"
            case .leagues: "New League"
            }
        }
    }

    @State private var mode: HubMode = .tournaments
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Hub", selection: $mode) {
                    ForEach(HubMode.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)

                listSection
            }
            .background(Color.courtDark)
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.mintAccent)
                    }
                    .accessibilityLabel(mode.newTitle)
                }
            }
            .navigationDestination(for: Tournament.self) { tournament in
                TournamentBracketView(tournament: tournament)
            }
            .navigationDestination(for: League.self) { league in
                LeagueDetailView(league: league)
            }
            .sheet(isPresented: $showingCreate) {
                createSheet
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .tint(Color.mintAccent)
    }

    @ViewBuilder
    private var listSection: some View {
        switch mode {
        case .tournaments:
            tournamentsList
        case .leagues:
            leaguesList
        }
    }

    @ViewBuilder
    private var createSheet: some View {
        switch mode {
        case .tournaments:
            CreateTournamentSheet(onCreate: createTournament)
        case .leagues:
            CreateLeagueSheet(onCreate: createLeague)
        }
    }

    private var tournamentsList: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if tournaments.isEmpty {
                    emptyState
                } else {
                    ForEach(tournaments) { tournament in
                        NavigationLink(value: tournament) {
                            TournamentCard(tournament: tournament)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(Spacing.md)
        }
    }

    private var leaguesList: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if leagues.isEmpty {
                    leagueEmptyState
                } else {
                    ForEach(leagues) { league in
                        NavigationLink(value: league) {
                            LeagueCard(league: league)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(Spacing.md)
        }
    }

    private var leagueEmptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "calendar.badge.clock")
                .font(Typography.displaySmall)
                .foregroundStyle(Color.orangeAccent)
            Text("No Leagues Yet")
                .font(Typography.headlineSmall)
                .foregroundStyle(Color.white)
            Text("Create a season-long round‑robin league and score it week by week.")
                .font(Typography.bodySmall)
                .foregroundStyle(Color.gray300)
                .multilineTextAlignment(.center)
            Button {
                showingCreate = true
            } label: {
                Text("Create League")
                    .font(Typography.labelLarge)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.mintAccent, in: Capsule())
                    .foregroundStyle(Color.courtDark)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "trophy.fill")
                .font(Typography.displaySmall)
                .foregroundStyle(Color.orangeAccent)
            Text("No Tournaments Yet")
                .font(Typography.headlineSmall)
                .foregroundStyle(Color.white)
            Text("Create a knockout bracket or a round‑robin league and watch the live S‑G‑P scorer drive it.")
                .font(Typography.bodySmall)
                .foregroundStyle(Color.gray300)
                .multilineTextAlignment(.center)
            Button {
                showingCreate = true
            } label: {
                Text("Create Tournament")
                    .font(Typography.labelLarge)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.mintAccent, in: Capsule())
                    .foregroundStyle(Color.courtDark)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: - Creation

    private func createTournament(name: String, type: TournamentType, setLength: Int, tieBreakLength: Int, seeded: Bool, entryPlayers: [Player]) {
        TournamentManager.shared.createTournament(
            name: name,
            type: type,
            setLength: setLength,
            tieBreakLength: tieBreakLength,
            seeded: seeded,
            entries: entryPlayers,
            in: modelContext
        )
        showingCreate = false
    }

    private func createLeague(name: String, roster: [Player]) {
        LeagueManager.shared.createLeague(name: name, roster: roster, in: modelContext)
        showingCreate = false
    }
}

// MARK: - Tournament Card

private struct TournamentCard: View {
    let tournament: Tournament

    private var championName: String {
        tournament.champion?.name ?? "—"
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: tournament.type.systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.mintAccent)
                .frame(width: 40, height: 40)
                .background(Color.courtMid, in: RoundedRectangle(cornerRadius: Radius.sm))

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(tournament.name)
                    .font(Typography.headlineSmall)
                    .foregroundStyle(Color.white)
                HStack(spacing: Spacing.xs) {
                    Text(tournament.type.title)
                        .font(Typography.captionSmall)
                        .foregroundStyle(Color.gray300)
                    Text("•")
                        .foregroundStyle(Color.gray500)
                    Text("\(tournament.entries.count) players")
                        .font(Typography.captionSmall)
                        .foregroundStyle(Color.gray300)
                    if tournament.isCompleted, let champion = tournament.champion {
                        Text("•")
                            .foregroundStyle(Color.gray500)
                        Label(champion.name, systemImage: "crown.fill")
                            .font(Typography.captionSmall)
                            .foregroundStyle(Color.orangeAccent)
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

// MARK: - Create Tournament Sheet

struct CreateTournamentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Player.name) private var players: [Player]

    @State private var name = ""
    @State private var type: TournamentType = .knockout
    @State private var setLength = 6
    @State private var tieBreakLength = 7
    @State private var seeded = false
    @State private var selectedPlayers: Set<Player.ID> = []

    let onCreate: (String, TournamentType, Int, Int, Bool, [Player]) -> Void

    private var selected: [Player] {
        players.filter { selectedPlayers.contains($0.id) }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Tournament Name", text: $name)
                    Picker("Format", selection: $type) {
                        ForEach(TournamentType.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Stepper("Sets to win: \(setLength)", value: $setLength, in: 2...6)
                    Stepper("Tie‑break to \(tieBreakLength)", value: $tieBreakLength, in: 7...10)
                    Toggle("Seeded draw", isOn: $seeded)
                }

                Section("Entries (\(selected.count))") {
                    ForEach(players) { player in
                        PlayerEntryRow(player: player, isSelected: selectedPlayers.contains(player.id)) { isOn in
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
            .navigationTitle("New Tournament")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name, type, setLength, tieBreakLength, seeded, selected)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selected.count < 2)
                }
            }
        }
        .tint(Color.mintAccent)
        .preferredColorScheme(.dark)
    }
}

private struct PlayerEntryRow: View {
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
