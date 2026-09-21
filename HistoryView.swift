import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Match> { $0.isCompleted }, sort: \Match.date, order: .reverse) private var matches: [Match]
    /// Store-filtered: the predicate above is evaluated in the SwiftData store,
    /// so completed matches arrive already filtered (no main-thread filtering,
    /// no full-table materialization). The `List` itself virtualizes rows.
    var completedMatches: [Match] { matches }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.courtDark.ignoresSafeArea()
                if completedMatches.isEmpty {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "tennisball",
                        description: Text("Completed matches will appear here.")
                    )
                    .foregroundStyle(.white)
                } else {
                    List {
                        ForEach(completedMatches) { match in
                            NavigationLink(destination: MatchDetailView(match: match)) {
                                matchCard(match)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.xs, leading: DesignSystem.Layout.screenPadding, bottom: DesignSystem.Spacing.xs, trailing: DesignSystem.Layout.screenPadding))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation(DesignSystem.Animation.springMedium) {
                                        modelContext.delete(match)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .foregroundStyle(.white)
                                .tint(DesignSystem.Colors.error)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                PDFShareButton(match: match) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                .tint(DesignSystem.Colors.info)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(DesignSystem.Colors.courtDark)
                }
            }
            .navigationTitle("Match History")
        }
    }
    
    private func matchCard(_ match: Match) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("\(match.playerOne.name) vs \(match.playerTwo.name)")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(.white)
                Text(match.setScores)
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundStyle(DesignSystem.Colors.mintAccent)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
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
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
        )
    }
}