import SwiftUI
import SwiftData
import Foundation

// MARK: - League List

struct LeagueListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \League.dateCreated, order: .reverse) private var leagues: [League]

    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    if leagues.isEmpty {
                        emptyState
                    } else {
                        ForEach(leagues) { league in
                            LeagueCard(league: league)
                        }
                    }
                }
                .padding(Spacing.md)
            }
            .background(Color.courtDark)
            .navigationTitle("Leagues")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.mintAccent)
                    }
                    .accessibilityLabel("New League")
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateLeagueSheet(onCreate: createLeague)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .tint(Color.mintAccent)
    }

    private var emptyState: some View {
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

    private func createLeague(name: String, roster: [Player]) {
        LeagueManager.shared.createLeague(name: name, roster: roster, in: modelContext)
        showingCreate = false
    }
}

// MARK: - League Card

private struct LeagueCard: View {
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

// MARK: - Create League Sheet

private struct CreateLeagueSheet: View {
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