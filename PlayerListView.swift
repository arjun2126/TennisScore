import SwiftUI
import SwiftData

/// Contacts-style Player Book: "My Card" pinned on top, alphabetized
/// opponents below, + to add, search filters opponents only.
struct PlayerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Player.name) private var players: [Player]
    @Query private var matches: [Match]
    @State private var searchText = ""
    @State private var showingAddPlayer = false
    @State private var newName = ""
    @State private var markAsMe = false
    
    /// When hosted as a primary tab there is nothing to dismiss.
    var showsDoneButton = true
    
    private var currentMe: Player? {
        players.first(where: { $0.isCurrentUser })
    }
    
    private var opponents: [Player] {
        players.filter { !$0.isCurrentUser }
    }
    
    private var filteredOpponents: [Player] {
        if searchText.isEmpty { return opponents }
        return opponents.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    /// Head-to-head record of Me vs an opponent (completed matches only).
    private func headToHead(vs opponent: Player, me: Player) -> (wins: Int, losses: Int) {
        let h2h = matches.filter { match in
            guard match.isCompleted else { return false }
            return (match.playerOne == me && match.playerTwo == opponent)
                || (match.playerOne == opponent && match.playerTwo == me)
        }
        let wins = h2h.filter { $0.winnerName == me.name }.count
        return (wins, h2h.count - wins)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.courtDark.ignoresSafeArea()
                VStack(spacing: 0) {
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
                    .padding(.top, DesignSystem.Spacing.sm)
                    .accessibilityLabel("Search players")
                    
                    // My Card: pinned on top, never filtered away.
                    if let me = currentMe {
                        myCard(me: me)
                    } else if !players.isEmpty {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(DesignSystem.Colors.warning)
                            Text("Tap ☆ on your name to set your profile")
                                .font(DesignSystem.Typography.captionMedium)
                                .foregroundStyle(DesignSystem.Colors.gray500)
                        }
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .accessibilityLabel("No profile set. Tap the star on your name to set your profile.")
                    }
                    
                    if opponents.isEmpty {
                        ContentUnavailableView(
                            "No Players",
                            systemImage: "person.slash",
                            description: Text(currentMe == nil ? "Your player book is empty. Tap + to add your profile." : "No rivals yet. Tap + to add opponents.")
                        )
                        .foregroundStyle(.white)
                        Spacer()
                    } else if filteredOpponents.isEmpty {
                        ContentUnavailableView(
                            "No Results",
                            systemImage: "magnifyingglass",
                            description: Text("No opponent matches \"\(searchText)\".")
                        )
                        .foregroundStyle(.white)
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredOpponents) { opponent in
                                opponentRow(opponent)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(DesignSystem.Colors.courtDark)
                    }
                }
            }
            .navigationTitle("Rivals")
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .font(DesignSystem.Typography.labelMedium)
                            .accessibilityLabel("Done")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { prepareAddPlayer() } label: {
                        Image(systemName: "plus")
                            .font(DesignSystem.Typography.labelLarge)
                            .bold()
                    }
                    .accessibilityLabel("Add player")
                    .accessibilityHint("Add a new player to your book")
                }
            }
            .sheet(isPresented: $showingAddPlayer) {
                addPlayerSheet
            }
        }
    }
    
// MARK: - Unified Card UI (one component; mint border marks primary)

    struct PlayerCardView<Accessory: View>: View {
        let name: String
        let subtitle: String
        let isPrimary: Bool
        @ViewBuilder let accessory: Accessory

        var body: some View {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: isPrimary ? "person.crop.circle.fill" : "person.circle.fill")
                    .font(.system(size: isPrimary ? 40 : 28))
                    .foregroundStyle(isPrimary ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.gray500)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxs) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text(name)
                            .font(isPrimary ? DesignSystem.Typography.headlineSmall : DesignSystem.Typography.bodyMedium)
                            .bold(isPrimary)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if isPrimary {
                            Text("YOU")
                                .font(DesignSystem.Typography.captionSmall)
                                .bold()
                                .padding(.horizontal, DesignSystem.Spacing.xs)
                                .padding(.vertical, 1)
                                .background(DesignSystem.Colors.mintAccent.opacity(0.25))
                                .foregroundStyle(DesignSystem.Colors.mintAccent)
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.gray500)
                        .lineLimit(1)
                }
                Spacer(minLength: DesignSystem.Spacing.xs)
                accessory
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                isPrimary
                    ? DesignSystem.Colors.mintAccent.opacity(0.08)
                    : DesignSystem.Colors.glassBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                    .stroke(
                        isPrimary
                            ? DesignSystem.Colors.mintAccent.opacity(0.5)
                            : DesignSystem.Colors.glassBorder,
                        lineWidth: isPrimary ? 1.5 : 1
                    )
            )
        }
    }

    // MARK: - My Card (pinned header, same component)

    private func myCard(me: Player) -> some View {
        let wins = matches.filter { $0.isCompleted && $0.winnerName == me.name }.count
        return PlayerCardView(
            name: me.name,
            subtitle: "\(me.matchCount) Matches • \(wins) Wins",
            isPrimary: true
        ) {
            EmptyView()
        }
        .padding(.horizontal, DesignSystem.Layout.screenPadding)
        .padding(.top, DesignSystem.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(me.name), your profile, \(me.matchCount) matches, \(wins) wins")
    }

    // MARK: - Opponent rows (same component)

    private func opponentRow(_ opponent: Player) -> some View {
        let subtitle: String
        let accessLabel: String
        if let me = currentMe {
            let record = headToHead(vs: opponent, me: me)
            subtitle = record.wins + record.losses == 0 ? "No matches yet" : "\(record.wins)-\(record.losses) vs you"
            accessLabel = "\(opponent.name), head to head \(record.wins) wins to \(record.losses) losses"
        } else {
            subtitle = "\(opponent.matchCount) Matches"
            accessLabel = "\(opponent.name), \(opponent.matchCount) matches"
        }
        return PlayerCardView(name: opponent.name, subtitle: subtitle, isPrimary: false) {
            Button {
                withAnimation(DesignSystem.Animation.springMedium) {
                    Player.setAsCurrentUser(opponent, in: modelContext)
                }
            } label: {
                Image(systemName: "star")
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundStyle(DesignSystem.Colors.gray500)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Set \(opponent.name) as your profile")
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessLabel)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation(DesignSystem.Animation.springMedium) {
                    for match in opponent.allMatches {
                        modelContext.delete(match)
                    }
                    modelContext.delete(opponent)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityLabel("Delete \(opponent.name)")
        }
    }
    
    // MARK: - Add Player
    
    private func prepareAddPlayer() {
        newName = ""
        markAsMe = currentMe == nil
        showingAddPlayer = true
    }
    
    private var addPlayerSheet: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.courtDark.ignoresSafeArea()
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 56))
                        .foregroundStyle(DesignSystem.Colors.mintAccent)
                        .accessibilityHidden(true)
                    Text("Add Player")
                        .font(DesignSystem.Typography.headlineMedium)
                        .bold()
                        .foregroundStyle(.white)
                    TextField("Player name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .font(DesignSystem.Typography.bodyMedium)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .accessibilityLabel("New player name")
                    Toggle(isOn: $markAsMe) {
                        Label("This is me", systemImage: "star.fill")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundStyle(.white)
                    }
                    .tint(DesignSystem.Colors.mintAccent)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .accessibilityLabel("Mark as your profile")
                    Button(action: saveNewPlayer) {
                        Text("Save Player")
                            .font(DesignSystem.Typography.labelLarge)
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(newName.trimmingCharacters(in: .whitespaces).isEmpty ? DesignSystem.Colors.gray500.opacity(0.3) : DesignSystem.Colors.mintAccent)
                            .foregroundStyle(newName.trimmingCharacters(in: .whitespaces).isEmpty ? .white : .black)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .accessibilityLabel("Save player")
                    Spacer()
                }
                .padding(.top, DesignSystem.Spacing.xl)
            }
            .navigationTitle("New Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddPlayer = false }
                        .font(DesignSystem.Typography.labelMedium)
                        .accessibilityLabel("Cancel")
                }
            }
        }
    }
    
    private func saveNewPlayer() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if let existing = players.first(where: { $0.name == name }) {
            if markAsMe {
                Player.setAsCurrentUser(existing, in: modelContext)
            } else {
                try? modelContext.save()
            }
        } else {
            let player = Player(name: name)
            modelContext.insert(player)
            if markAsMe {
                Player.setAsCurrentUser(player, in: modelContext)
            } else {
                try? modelContext.save()
            }
        }
        showingAddPlayer = false
    }
}
