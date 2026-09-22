import SwiftUI
import SwiftData
import UIKit
import CoreImage

// MARK: - Events tab hub (browse + my events; Phase 3)

struct EventListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Event.createdAt, order: .reverse) private var events: [Event]
    @Query(sort: \EventRegistration.joinedAt, order: .reverse) private var registrations: [EventRegistration]

    @State private var mode: EventHubMode = .explore
    @State private var showingCreate = false
    @State private var editingEvent: Event?

    private enum EventHubMode: String, CaseIterable, Identifiable {
        case explore, mine
        var id: String { rawValue }
        var title: String { self == .explore ? "Explore" : "My Events" }
    }

    private var myEvents: [Event] {
        let mine = events.filter { EventManager.isOwner($0, name: EventManager.currentPlayerName(context: context)) }
        let joined = registrations
            .filter { $0.status == .confirmed || $0.status == .waitlisted }
            .compactMap(\.event)
        return Array(Set(mine).union(Set(joined))).sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(EventHubMode.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                switch mode {
                case .explore:
                    EventExploreView()
                case .mine:
                    myEventsList
                }
            }
            .background(DesignSystem.Colors.courtDark)
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.mintAccent)
                    }
                    .accessibilityLabel("Create event")
                }
            }
            .fullScreenCover(isPresented: $showingCreate) {
                CreateEventWizard()
            }
            .fullScreenCover(item: $editingEvent) { event in
                CreateEventWizard(editing: event)
            }
        }
    }

    private var myEventsList: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.md) {
                if myEvents.isEmpty {
                    emptyMine
                } else {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(myEvents) { event in
                            NavigationLink {
                                EventDetailView(event: event)
                            } label: {
                                EventRow(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
    }

    private var emptyMine: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(DesignSystem.Colors.mintAccentDim)
            Text("Nothing here yet")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundStyle(DesignSystem.Colors.gray900)
            Text("Create an event or join one from Explore — it'll appear in My Events.")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundStyle(DesignSystem.Colors.gray500)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DesignSystem.Spacing.xxxl)
    }
}

struct EventRow: View {
    let event: Event

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: event.eventType.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.mintAccent)
                .frame(width: 40, height: 40)
                .background(DesignSystem.Colors.mintAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(event.name)
                    .font(DesignSystem.Typography.headlineSmall)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(event.eventType.title) · \(event.dateLine)")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.gray500)
                Text(event.feeLine)
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxs) {
                EventStatusChip(status: event.status)
                EventVisibilityChip(visibility: event.visibility)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.glassBackground)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.glassBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
    }
}

// MARK: - Event detail

struct EventDetailView: View {
    @Environment(\.modelContext) private var context
    let event: Event

    @State private var showingEdit = false
    @State private var errorText: String?
    @State private var copiedLink = false
    @State private var showingJoin = false
    @State private var showingReport = false
    @State private var joinFeedback: String?
    @State private var resultMatch: EventMatch?
    @State private var disputeMatch: EventMatch?
    @State private var scheduleMessage: String?

    private var myName: String { EventManager.currentPlayerName(context: context) }
    private var isOwner: Bool { EventManager.isOwner(event, name: myName) }
    private var myRegistration: EventRegistration? { EventManager.registration(event, name: myName) }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.md) {
                summaryCard
                statusBanner
                if isOwner {
                    ownerManageCard
                } else if event.status == .published {
                    joinCard
                }
                rosterCard
                scheduleCard
                if !event.matches.isEmpty {
                    standingsCard
                }
                metaGrid
                feesCard
                rulesCard
                shareCard
            }
            .padding(DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.courtDark)
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        switch event.status {
                        case .draft:
                            Button { attemptPublish() } label: { Label("Publish", systemImage: "paperplane.fill") }
                            Button(role: .destructive) { EventManager.cancel(event, context: context) } label: { Label("Cancel Event", systemImage: "xmark.circle") }
                        case .published:
                            Button { EventManager.unpublish(event, context: context) } label: { Label("Unpublish", systemImage: "arrow.uturn.backward") }
                            Button(role: .destructive) { EventManager.cancel(event, context: context) } label: { Label("Cancel Event", systemImage: "xmark.circle") }
                        default:
                            Button { EventManager.unpublish(event, context: context) } label: { Label("Reopen as Draft", systemImage: "arrow.uturn.backward") }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(DesignSystem.Colors.mintAccent)
                    }
                }
            } else if event.visibility == .publicEvent {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingReport = true
                    } label: {
                        Image(systemName: "flag")
                            .foregroundStyle(DesignSystem.Colors.gray900)
                    }
                    .accessibilityLabel("Report event")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            CreateEventWizard(editing: event)
        }
        .sheet(isPresented: $showingJoin) {
            JoinEventSheet(event: event, onConfirm: performJoin, onPaid: { message in
                joinFeedback = message
            })
        }
        .sheet(isPresented: $showingReport) {
            ReportEventSheet(event: event)
        }
        .sheet(item: $resultMatch) { match in
            MatchResultSheet(match: match, event: event)
        }
        .sheet(item: $disputeMatch) { match in
            MatchDisputeSheet(match: match, event: event)
        }
        .alert("Can't Publish", isPresented: .init(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
        .alert("Joined", isPresented: .init(get: { joinFeedback != nil }, set: { if !$0 { joinFeedback = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(joinFeedback ?? "")
        }
        .animation(DesignSystem.Animation.easeOutFast, value: event.registrations.count)
    }

    private func performJoin() {
        let status = EventManager.join(event, name: myName, context: context)
        joinFeedback = status == .confirmed
            ? "You're in! Spot confirmed. We'll remind you before start time."
            : "The event is full — you're on the waitlist. We'll let you know if a spot opens."
    }

    private func attemptPublish() {
        if let error = EventManager.publish(event, context: context) {
            errorText = error
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: event.eventType.symbol)
                    .foregroundStyle(DesignSystem.Colors.mintAccent)
                Text(event.eventType.title)
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundStyle(DesignSystem.Colors.mintAccent)
                Spacer()
                EventStatusChip(status: event.status)
            }
            Text(event.name)
                .font(DesignSystem.Typography.displaySmall)
                .foregroundStyle(.white)
            if !event.summary.isEmpty {
                Text(event.summary)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            }
            Text("Hosted by \(event.createdByName.isEmpty ? "Me" : event.createdByName)")
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.gray500)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var statusBanner: some View {
        Group {
            switch event.status {
            case .draft:
                Text("Only you can see this draft. Publish from the ⋯ menu to make it discoverable or shareable.")
            case .cancelled:
                Text("This event was cancelled.")
            case .completed:
                Text("This event has ended.")
            case .published:
                EmptyView()
            }
        }
        .font(DesignSystem.Typography.bodySmall)
        .foregroundStyle(event.status == .draft ? DesignSystem.Colors.gray900 : DesignSystem.Colors.gray500)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let reg = myRegistration {
                Label(reg.status == .confirmed ? "You're in — spot confirmed" : "You're on the waitlist",
                      systemImage: reg.status == .confirmed ? "checkmark.seal.fill" : "clock.badge.questionmark")
                    .font(DesignSystem.Typography.labelLarge)
                    .foregroundStyle(reg.status == .confirmed ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.gray900)
                if EventManager.isFull(event), reg.status == .confirmed {
                    Text("This event is now full. You're safely confirmed.")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundStyle(DesignSystem.Colors.gray500)
                }
                Button(role: .destructive) {
                    EventManager.leave(event, name: myName, context: context)
                } label: {
                    Label("Leave Event", systemImage: "arrow.uturn.backward")
                        .font(DesignSystem.Typography.labelLarge)
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Label("Join this event", systemImage: "person.badge.plus")
                    .font(DesignSystem.Typography.labelLarge)
                    .foregroundStyle(DesignSystem.Colors.gray900)
                FeeBreakdownLine(event: event)
                Text("You'll pay the total via Apple In-App Purchase. The price shown is exactly what Apple charges — refunds go through Apple's Report a Problem before the event.")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.gray500)
                Button {
                    showingJoin = true
                } label: {
                    Label(EventManager.isFull(event) ? "Join Waitlist" : "Join Event", systemImage: "hand.tap")
                        .font(DesignSystem.Typography.labelLarge)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var ownerManageCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Organiser", systemImage: "person.2.badge.gearshape")
                .font(DesignSystem.Typography.labelLarge)
                .foregroundStyle(DesignSystem.Colors.gray900)
            Text("\(EventManager.confirmedCount(event)) confirmed · \(EventManager.waitlistCount(event)) waitlisted · capacity \(event.maxPlayers)")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundStyle(DesignSystem.Colors.gray500)
            if event.status == .published {
                Button {
                    showingEdit = true
                } label: {
                    Label("Edit Event Details", systemImage: "pencil")
                        .font(DesignSystem.Typography.labelLarge)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var rosterCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Label("Roster", systemImage: "person.3")
                    .font(DesignSystem.Typography.labelLarge)
                    .foregroundStyle(DesignSystem.Colors.gray900)
                Spacer()
                Text("\(EventManager.joinedRoster(event).count)/\(event.maxPlayers)")
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            }
            let roster = EventManager.joinedRoster(event)
            if roster.isEmpty {
                Text("No players yet.")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            } else {
                ForEach(roster) { reg in
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Circle()
                            .fill(reg.status == .confirmed ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.warning)
                            .frame(width: 8, height: 8)
                        Text(reg.playerName)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundStyle(DesignSystem.Colors.gray900)
                        Spacer()
                        Text(reg.status == .confirmed ? "In" : "Waitlist")
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                        if isOwner, reg.playerName != event.createdByName {
                            Button {
                                EventManager.cancelRegistration(reg, context: context)
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(DesignSystem.Colors.gray500)
                            }
                            .accessibilityLabel("Remove \(reg.playerName)")
                        }
                    }
                }
                if EventManager.waitlistCount(event) > 0 {
                    Text("We notify the next waitlisted player atomically when a spot opens (Phase 4).")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.gray500)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var scheduleCard: some View {
        let matches = event.matches.sorted {
            if $0.round != $1.round { return $0.round < $1.round }
            return $0.scheduledAt < $1.scheduledAt
        }
        let nextRound = (event.matches.map(\.round).max() ?? 0) + 1
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Label("Schedule", systemImage: "list.number")
                    .font(DesignSystem.Typography.labelLarge)
                    .foregroundStyle(DesignSystem.Colors.gray900)
                Spacer()
                Text("\(matches.count) matches")
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            }
            if matches.isEmpty {
                if isOwner {
                    Text("Auto-generate a draw from the confirmed roster below.")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundStyle(DesignSystem.Colors.gray500)
                    Button {
                        generateDraw()
                    } label: {
                        Label(event.eventType == .tournament ? "Generate Bracket" : "Generate Round-Robin", systemImage: "wand.and.stars")
                            .font(DesignSystem.Typography.labelLarge)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(EventManager.confirmedNames(event).count < 2)
                } else {
                    Text("The organiser hasn't posted a schedule yet.")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundStyle(DesignSystem.Colors.gray500)
                }
            } else {
                ForEach(groupedRounds(matches), id: \.roundNumber) { group in
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text("Round \(group.roundNumber)")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundStyle(DesignSystem.Colors.mintAccent)
                        ForEach(group.matches) { match in
                            matchRow(match)
                            Divider().overlay(DesignSystem.Colors.glassBorder)
                        }
                    }
                }
                if isOwner, event.eventType == .tournament {
                    if event.matches.allSatisfy({ $0.round < nextRound || $0.status == .played }) {
                        Button {
                            let advanced = EventManager.advanceBracket(event, context: context)
                            scheduleMessage = advanced ? "Advanced bracket to round \(nextRound)." : "All winners need to be recorded first."
                        } label: {
                            Label("Advance to Round \(nextRound)", systemImage: "forward.end.fill")
                                .font(DesignSystem.Typography.labelLarge)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .alert("Schedule", isPresented: .init(get: { scheduleMessage != nil }, set: { if !$0 { scheduleMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(scheduleMessage ?? "")
        }
    }

    private func groupedRounds(_ matches: [EventMatch]) -> [(roundNumber: Int, matches: [EventMatch])] {
        let rounds = Array(Set(matches.map(\.round))).sorted()
        return rounds.map { round in
            (round, matches.filter { $0.round == round })
        }
    }

    private func matchRow(_ match: EventMatch) -> some View {
        let isMine = match.playerAName == myName || match.playerBName == myName
        return HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(match.playerAName) vs \(match.playerBName)")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.gray900)
                Text(match.isPlayed ? match.scoreLine() : "R\(match.round) · \(match.scheduledAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundStyle(match.isPlayed ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.gray500)
                if match.status == .disputed, let note = match.disputeNote {
                    Text("⚠️ Disputed — \(note)")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundStyle(DesignSystem.Colors.warning)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if match.isPlayed {
                    Text("✔ \(match.winnerName ?? "")")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundStyle(DesignSystem.Colors.mintAccent)
                }
                if isOwner {
                    Button {
                        resultMatch = match
                    } label: {
                        Text(match.isPlayed ? "Update" : "Score")
                            .font(DesignSystem.Typography.labelSmall)
                    }
                    .foregroundStyle(DesignSystem.Colors.mintAccent)
                } else if isMine {
                    Button {
                        disputeMatch = match
                    } label: {
                        Image(systemName: "flag")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(DesignSystem.Colors.gray500)
                    .accessibilityLabel("Flag score")
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func generateDraw() {
        if event.eventType == .tournament {
            EventManager.generateBracket(event, context: context)
        } else {
            EventManager.generateRoundRobin(event, context: context)
        }
    }

    private var standingsCard: some View {
        let rows = EventStandings.standings(for: event)
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Live Standings", systemImage: "chart.bar.fill")
                .font(DesignSystem.Typography.labelLarge)
                .foregroundStyle(DesignSystem.Colors.gray900)
            if rows.isEmpty {
                Text("Results will appear here as matches are scored.")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.name) { index, row in
                    HStack {
                        Text("\(index + 1)")
                            .font(DesignSystem.Typography.monoSmall)
                            .foregroundStyle(index < 3 ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.gray500)
                            .frame(width: 24, alignment: .leading)
                        Text(row.name)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundStyle(DesignSystem.Colors.gray900)
                        Spacer()
                        Text("\(row.wins)-\(row.losses)")
                            .font(DesignSystem.Typography.monoSmall)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                        Text("\(row.points) pts")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundStyle(DesignSystem.Colors.mintAccent)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
                Text("Disputed or unfinished matches don't count toward standings.")
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var metaGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.sm) {
            MetaTile(icon: "calendar", title: "Dates", value: event.dateLine)
            MetaTile(icon: "mappin.circle", title: "Location", value: event.locationLabel.isEmpty ? "TBD" : event.locationLabel)
            MetaTile(icon: "person.3", title: "Capacity", value: "\(event.maxPlayers) players")
            MetaTile(icon: "slider.horizontal.3", title: "Eligibility", value: event.eligibilityLine)
            MetaTile(icon: "flag.2.crossed", title: "Format", value: event.rulesDetail.isEmpty ? "Custom rules" : event.rulesDetail)
            MetaTile(icon: "checklist", title: "Register by", value: event.regDeadline.formatted(date: .abbreviated, time: .omitted))
        }
    }

    private var feesCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Fees (display only)", systemImage: "dollarsign.circle")
                .font(DesignSystem.Typography.labelLarge)
                .foregroundStyle(DesignSystem.Colors.gray900)
            FeeBreakdownList(event: event)
            Text("Entry is paid via Apple In-App Purchase. Refunds go through Apple before the event starts.")
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.gray500)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Policies", systemImage: "shield.checkered")
                .font(DesignSystem.Typography.labelLarge)
                .foregroundStyle(DesignSystem.Colors.gray900)
            PolicyRow(icon: event.visibility == .publicEvent ? "globe" : "lock.fill", text: event.visibility == .publicEvent ? "Public event — reviewed before appearing to players" : "Private event — shareable by link")
            PolicyRow(icon: "person.crop.circle.badge.checkmark", text: event.isMinorSpace ? "Allows ages \(event.ageMin)–17 with creator parental-consent attestation" : "18+ only")
            PolicyRow(icon: event.ratingOn ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis", text: event.ratingOn ? "Rated event — updates player skill ratings" : "Unrated (friendly)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var shareCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Label("Share", systemImage: "square.and.arrow.up")
                .font(DesignSystem.Typography.labelLarge)
                .foregroundStyle(DesignSystem.Colors.gray900)
            QRCodeView(string: EventLink.url(shareToken: event.shareToken).absoluteString)
                .frame(width: 160, height: 160)
                .frame(maxWidth: .infinity)
            HStack(spacing: DesignSystem.Spacing.sm) {
                ShareLink(item: EventLink.url(shareToken: event.shareToken)) {
                    Label("Share Link", systemImage: "square.and.arrow.up")
                        .font(DesignSystem.Typography.labelLarge)
                }
                .buttonStyle(PrimaryButtonStyle())
                Button {
                    UIPasteboard.general.string = EventLink.url(shareToken: event.shareToken).absoluteString
                    copiedLink = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        copiedLink = false
                    }
                } label: {
                    Label(copiedLink ? "Copied" : "Copy", systemImage: copiedLink ? "checkmark" : "doc.on.doc")
                        .font(DesignSystem.Typography.labelLarge)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            if event.status == .published {
                Button {
                    showingEdit = true
                } label: {
                    Label("Edit Event", systemImage: "pencil")
                        .font(DesignSystem.Typography.labelLarge)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

/// Presented by deep links (`vantage://event/<token>`) and finds the target
/// event by share token.
struct EventDetailHostView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var matches: [Event]

    private let token: String

    init(token: String) {
        self.token = token
        let predicate = #Predicate<Event> { $0.shareToken == token }
        _matches = Query(filter: predicate)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let event = matches.first {
                    EventDetailView(event: event)
                } else {
                    ContentUnavailableView(
                        "Event Not Found",
                        systemImage: "magnifyingglass",
                        description: Text("This link doesn't match any event on this device.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Create / Edit wizard

struct CreateEventWizard: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let editing: Event?
    @State private var config = EventDraftConfig()
    @State private var didLoadEditing = false
    @State private var step = 1
    @State private var stepError: String?
    @State private var publishError: String?
    @State private var showingPublishError = false
    @State private var showingMapPicker = false

    private let maxSteps = 5

    init(editing: Event? = nil) {
        self.editing = editing
    }

    private var isEditing: Bool { editing != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progress
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.top, DesignSystem.Spacing.sm)
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        stepContent
                        if let stepError {
                            Text(stepError)
                                .font(DesignSystem.Typography.captionMedium)
                                .foregroundStyle(DesignSystem.Colors.error)
                        }
                        if config.isMinorSpace {
                            minorNotice
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                }
                .scrollDismissesKeyboard(.automatic)
                footer
            }
            .background(DesignSystem.Colors.courtDark)
            .navigationTitle(isEditing ? "Edit Event" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !didLoadEditing else { return }
                didLoadEditing = true
                if let editing {
                    config = EventDraftConfig(from: editing)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.gray900)
                }
            }
            .alert("Can't Publish", isPresented: $showingPublishError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(publishError ?? "")
            }
            .sheet(isPresented: $showingMapPicker) {
                LocationPickerMap(
                    initialLatitude: config.latitude,
                    initialLongitude: config.longitude
                ) { lat, lon in
                    config.latitude = lat
                    config.longitude = lon
                }
                .presentationDetents([.large])
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 1: typeStep
        case 2: detailsStep
        case 3: rulesStep
        case 4: feesStep
        default: visibilityStep
        }
    }

    private func goForward() {
        if let error = config.validationMessage(forStep: step) {
            stepError = error
            return
        }
        stepError = nil
        withAnimation(DesignSystem.Animation.easeOutFast) {
            step += 1
        }
    }

    private func finish(publish: Bool) {
        if let event = editing {
            EventManager.apply(config, to: event, context: context)
            if publish {
                if let error = EventManager.publish(event, context: context) {
                    publishError = error
                    showingPublishError = true
                    return
                }
            }
            dismiss()
        } else {
            let event = Event(
                name: config.name,
                summary: config.summary,
                eventType: config.eventType,
                rulesDetail: config.formatPreset.title,
                maxPlayers: config.maxPlayers,
                startDate: config.startDate,
                endDate: config.endDate,
                regDeadline: config.regDeadline,
                locationLabel: config.location,
                skillMin: config.skillMin,
                skillMax: config.skillMax,
                ageMin: config.ageMin,
                ageMax: config.ageMax,
                ratingOn: config.ratingOn,
                entryFeeCents: EventFees.cents(fromDollars: config.entryFeeDollars),
                feeMode: config.feeMode,
                convenienceFeePercent: config.feePercent,
                convenienceFeeFlatCents: EventFees.cents(fromDollars: config.feeFlatDollars),
                visibility: config.visibility,
                attestMinorConsent: config.attestMinorConsent,
                createdByName: EventManager.ownerStamp(context: context)
            )
            context.insert(event)
            try? context.save()
            if publish {
                if let error = EventManager.publish(event, context: context) {
                    publishError = error
                    showingPublishError = true
                    return
                }
            }
            dismiss()
        }
    }

    // MARK: Steps

    private var typeStep: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("What kind of event?")
                .font(DesignSystem.Typography.headlineMedium)
                .foregroundStyle(.white)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.sm) {
                ForEach(VantageEventType.allCases) { type in
                    Button {
                        config.eventType = type
                        config.formatPreset = EventFormatPreset.options(for: type).first ?? .customRules
                    } label: {
                        VStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: type.symbol)
                                .font(.system(size: 24))
                            Text(type.title)
                                .font(DesignSystem.Typography.labelMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                                .fill(config.eventType == type ? DesignSystem.Colors.mintAccent.opacity(0.15) : DesignSystem.Colors.glassBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                                        .stroke(config.eventType == type ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.glassBorder, lineWidth: 1)
                                )
                        )
                        .foregroundStyle(config.eventType == type ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.gray900)
                    }
                    .buttonStyle(.plain)
                }
            }
            WizardField(label: "Event name") {
                TextField("e.g. Saturday Singles", text: $config.name)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.next)
                    .accessibilityLabel("Event name")
                    .accessibilityHint("e.g. Saturday Singles")
            }
        }
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Event details")
                .font(DesignSystem.Typography.headlineMedium)
                .foregroundStyle(.white)
            WizardField(label: "Description (optional)") {
                TextField("Format, vibe, anything players should know", text: $config.summary, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
            }
            WizardField(label: "Location (label)") {
                TextField("Whitby Tennis Club, Court 1", text: $config.location)
                    .textFieldStyle(.roundedBorder)
            }
            WizardField(label: "Map pin") {
                Button {
                    showingMapPicker = true
                } label: {
                    HStack {
                        Image(systemName: config.latitude == nil ? "mappin.slash" : "mappin.and.ellipse")
                        Text(config.latitude == nil ? "Set location on map" : "Map pin set")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.gray900)
                }
            }
            WizardField(label: "Capacity") {
                Stepper(value: $config.maxPlayers, in: 2...128) {
                    Text("\(config.maxPlayers) players")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.gray900)
                }
            }
            DatePicker("Starts", selection: $config.startDate, displayedComponents: .date)
            DatePicker("Ends", selection: $config.endDate, displayedComponents: .date)
            DatePicker("Registers by", selection: $config.regDeadline, displayedComponents: .date)
                .font(DesignSystem.Typography.bodyMedium)
        }
    }

    private var rulesStep: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Rules & eligibility")
                .font(DesignSystem.Typography.headlineMedium)
                .foregroundStyle(.white)
            WizardField(label: "Format preset") {
                Picker("Format", selection: $config.formatPreset) {
                    ForEach(EventFormatPreset.options(for: config.eventType)) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .tint(DesignSystem.Colors.mintAccent)
            }
            WizardField(label: "Skill band") {
                Stepper(value: $config.skillMin, in: 1...10) {
                    Text("Min skill \(config.skillMin)")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.gray900)
                }
                Stepper(value: $config.skillMax, in: 1...10) {
                    Text("Max skill \(config.skillMax)")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.gray900)
                }
            }
            WizardField(label: "Age band (minimum 13)") {
                Stepper(value: $config.ageMin, in: 13...100) {
                    Text("Min age \(config.ageMin)")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.gray900)
                }
                Stepper(value: $config.ageMax, in: 13...100) {
                    Text("Max age \(config.ageMax)")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.gray900)
                }
            }
            Toggle(isOn: $config.ratingOn) {
                Label("Rated event", systemImage: "chart.line.uptrend.xyaxis")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.gray900)
            }
            .tint(DesignSystem.Colors.mintAccent)
        }
    }

    private var feesStep: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Fees")
                .font(DesignSystem.Typography.headlineMedium)
                .foregroundStyle(.white)
            WizardField(label: "Entry fee") {
                HStack {
                    Text("$")
                        .font(DesignSystem.Typography.bodyLarge)
                        .foregroundStyle(DesignSystem.Colors.gray500)
                    TextField("0.00", text: $config.entryFeeDollars)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
            }
            WizardField(label: "Convenience fee mode") {
                Picker("Mode", selection: $config.feeMode) {
                    ForEach(EventFeeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            switch config.feeMode {
            case .percent:
                WizardField(label: "Percent of entry") {
                    HStack {
                        Slider(value: $config.feePercent, in: 0...50, step: 1)
                        Text("\(Int(config.feePercent))%")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundStyle(DesignSystem.Colors.mintAccent)
                            .frame(width: 48)
                    }
                }
            case .flat:
                WizardField(label: "Per-player fee") {
                    HStack {
                        Text("$")
                            .font(DesignSystem.Typography.bodyLarge)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                        TextField("3.00", text: $config.feeFlatDollars)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            FeeBreakdownList(event: nil, entryCents: config.entryCents, feeCents: config.feeCents, totalCents: config.totalCents)
        }
    }

    private var visibilityStep: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Visibility & publish")
                .font(DesignSystem.Typography.headlineMedium)
                .foregroundStyle(.white)
            WizardField(label: "Who can see it?") {
                Picker("Visibility", selection: $config.visibility) {
                    Text(EventVisibility.privateEvent.title).tag(EventVisibility.privateEvent)
                    Text(EventVisibility.publicEvent.title).tag(EventVisibility.publicEvent)
                }
                .pickerStyle(.segmented)
            }
            Text(config.visibility == .publicEvent
                 ? "Public events appear to everyone after a quick review. Restricted to players 18 and older."
                 : "Private events are shared by link — only invited players can find them.")
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.gray500)
            if config.isMinorSpace {
                Toggle(isOn: $config.attestMinorConsent) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text("I confirm parental consent for all minors")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundStyle(DesignSystem.Colors.gray900)
                        Text("Required — this event allows ages \(config.ageMin)–17 and must stay private.")
                            .font(DesignSystem.Typography.captionSmall)
                            .foregroundStyle(DesignSystem.Colors.warning)
                    }
                }
                .tint(DesignSystem.Colors.mintAccent)
            }
        }
    }

    private var minorNotice: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(DesignSystem.Colors.warning)
            Text("Ages under 18 are only allowed in private events with your signed parental-consent attestation.")
                .font(DesignSystem.Typography.captionSmall)
                .foregroundStyle(DesignSystem.Colors.warning)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.warning.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
    }

    private var progress: some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            ForEach(1...maxSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.gray100)
                    .frame(height: 4)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if step > 1 {
                Button {
                    stepError = nil
                    withAnimation(DesignSystem.Animation.easeOutFast) { step -= 1 }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 110)
            }
            if step < maxSteps {
                Button {
                    goForward()
                } label: {
                    Label("Continue", systemImage: "chevron.right")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button {
                    finish(publish: false)
                } label: {
                    Text("Save as Draft")
                }
                .buttonStyle(SecondaryButtonStyle())
                Button {
                    finish(publish: true)
                } label: {
                    Text(isEditing ? "Save & Publish" : "Publish")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.courtMid)
    }
}

// MARK: - Supporting pieces

struct EventStatusChip: View {
    let status: EventStatus
    var body: some View {
        StatusBadge(
            text: status.title.uppercased(),
            color: statusColor,
            icon: statusSymbol
        )
    }
    private var statusColor: Color {
        switch status {
        case .draft: return DesignSystem.Colors.gray500
        case .published: return DesignSystem.Colors.success
        case .cancelled: return DesignSystem.Colors.error
        case .completed: return DesignSystem.Colors.info
        }
    }
    private var statusSymbol: String {
        switch status {
        case .draft: return "pencil"
        case .published: return "checkmark"
        case .cancelled: return "xmark"
        case .completed: return "flag.checkered"
        }
    }
}

struct EventVisibilityChip: View {
    let visibility: EventVisibility
    var body: some View {
        StatusBadge(
            text: visibility.title.uppercased(),
            color: visibility == .publicEvent ? DesignSystem.Colors.info : DesignSystem.Colors.gray500,
            icon: visibility == .publicEvent ? "globe" : "lock.fill"
        )
    }
}

struct MetaTile: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Label(title, systemImage: icon)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundStyle(DesignSystem.Colors.gray500)
            Text(value)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundStyle(DesignSystem.Colors.gray900)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }
}

struct PolicyRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(DesignSystem.Colors.mintAccent)
                .frame(width: 22)
            Text(text)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundStyle(DesignSystem.Colors.gray900)
            Spacer(minLength: 0)
        }
    }
}

struct WizardField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(label)
                .font(DesignSystem.Typography.labelMedium)
                .foregroundStyle(DesignSystem.Colors.gray500)
            content
        }
    }
}

/// Line-item breakdown shown on detail pages and in the wizard.
/// Compact one-line fee summary used inside the join card.
struct FeeBreakdownLine: View {
    let event: Event

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            Image(systemName: "dollarsign.circle")
                .foregroundStyle(DesignSystem.Colors.mintAccent)
            Text(feeLine)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundStyle(DesignSystem.Colors.gray900)
        }
    }

    private var feeLine: String {
        if event.totalCents > 0 {
            return "\(EventFees.currencyString(event.totalCents)) total — \(EventFees.currencyString(event.entryFeeCents)) entry + \(EventFees.currencyString(event.convenienceFeeCents)) convenience fee"
        }
        return "Free entry"
    }
}

struct FeeBreakdownList: View {
    let event: Event?
    let entryCents: Int64
    let feeCents: Int64
    let totalCents: Int64

    init(event: Event?, entryCents: Int64, feeCents: Int64, totalCents: Int64) {
        self.event = event
        self.entryCents = entryCents
        self.feeCents = feeCents
        self.totalCents = totalCents
    }

    init(event: Event) {
        self.event = event
        self.entryCents = event.entryFeeCents
        self.feeCents = event.convenienceFeeCents
        self.totalCents = event.totalCents
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            row("Entry fee", EventFees.currencyString(entryCents))
            row("Convenience fee (\(feePercentText))", EventFees.currencyString(feeCents))
            Divider().overlay(DesignSystem.Colors.glassBorder)
            row("Total per player", EventFees.currencyString(totalCents), emphasized: true)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.courtMid.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    private var feePercentText: String {
        if let event, event.feeMode == .flat {
            return "flat"
        }
        if let event {
            return "\(Int(event.convenienceFeePercent))%"
        }
        return "Player pays fee + entry"
    }

    private func row(_ title: String, _ value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(emphasized ? DesignSystem.Typography.labelLarge : DesignSystem.Typography.bodySmall)
                .foregroundStyle(emphasized ? .white : DesignSystem.Colors.gray500)
            Spacer()
            Text(value)
                .font(emphasized ? DesignSystem.Typography.labelLarge : DesignSystem.Typography.bodySmall)
                .foregroundStyle(emphasized ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.gray900)
        }
    }
}

// MARK: - QR code

struct QRCodeView: UIViewRepresentable {
    let string: String

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .white
        view.layer.cornerRadius = DesignSystem.Radius.sm
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = Self.makeQR(string)
    }

    static func makeQR(_ string: String) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale: CGFloat = 4
        let image = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return UIImage(ciImage: image)
    }
}