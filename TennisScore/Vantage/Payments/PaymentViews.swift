import SwiftUI
import SwiftData

// MARK: - Creator Dashboard (Phase 4: settle Path 1 manual payouts)

struct CreatorDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Event.createdAt, order: .reverse) private var events: [Event]
    @Query(sort: \PayoutRecord.createdAt, order: .reverse) private var payouts: [PayoutRecord]

    @State private var toast: String?
    @State private var newEvent: Event?

    private var myName: String { EventManager.currentPlayerName(context: context) }

    private var owned: [Event] {
        events.filter { EventManager.isOwner($0, name: myName) }
    }

    private var collectedEntryCents: Int64 {
        owned.reduce(0) { $0 + EventManager.entryCollectedCents($1) }
    }

    private var collectedFeeCents: Int64 {
        owned.reduce(0) { $0 + EventManager.feeCollectedCents($1) }
    }

    private var paidOutCents: Int64 {
        payouts.reduce(0) { $0 + $1.amountCents }
    }

    private var pendingPayoutCents: Int64 {
        max(0, collectedEntryCents - paidOutCents)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.md) {
                    if owned.isEmpty {
                        creatorActionCard
                    } else {
                        if hasPaidRegistrations { earningsCard }
                        payoutCard
                        perEventCard
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Colors.courtDark)
            .navigationTitle("Creator")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let event = Event(name: "", summary: "", eventType: .tournament)
                        context.insert(event)
                        newEvent = event
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.mintAccent)
                    }
                    .accessibilityLabel("Create event")
                }
            }
            .fullScreenCover(item: $newEvent) { event in
                CreateEventWizard(editing: event)
            }
            .alert("Payout logged", isPresented: .init(get: { toast != nil }, set: { if !$0 { toast = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(toast ?? "")
            }
        }
    }

    private var hasPaidRegistrations: Bool { collectedEntryCents > 0 }

    private var earningsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Label("Earnings", systemImage: "dollarsign.circle.fill")
                .font(DesignSystem.Typography.labelLarge)
                .foregroundStyle(DesignSystem.Colors.gray900)
            HStack(spacing: DesignSystem.Spacing.sm) {
                statTile("Gross entry fees", EventFees.currencyString(collectedEntryCents), icon: "dollarsign.circle.fill")
                statTile("Platform fee", EventFees.currencyString(collectedFeeCents), icon: "percent")
            }
            HStack(spacing: DesignSystem.Spacing.sm) {
                statTile("Pending creator amount", EventFees.currencyString(pendingPayoutCents), icon: "clock.fill", highlight: true)
                statTile("Paid amount", EventFees.currencyString(paidOutCents), icon: "checkmark.circle.fill")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var creatorActionCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Image(systemName: "sportscourt.fill")
                .font(.system(size: 36))
                .foregroundStyle(DesignSystem.Colors.mintAccent)
            Text("Create your first event")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundStyle(DesignSystem.Colors.gray900)
            Text("Organize a tournament, league, ladder, or custom event.")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundStyle(DesignSystem.Colors.gray500)
                .multilineTextAlignment(.center)
            Button {
                let event = Event(name: "", summary: "", eventType: .tournament)
                context.insert(event)
                newEvent = event
            } label: {
                Label("Create Event", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .padding(.top, DesignSystem.Spacing.xxl)
    }

    private var payoutsFor: [PayoutRecord] {
        payouts.filter { payout in
            owned.contains { event in event.shareToken == payout.eventToken }
        }
    }

    private var payoutCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Payouts", systemImage: "list.clipboard")
                .font(DesignSystem.Typography.labelLarge)
                .foregroundStyle(DesignSystem.Colors.gray900)
            if payoutsFor.isEmpty {
                Text("None yet.")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            } else {
                ForEach(payoutsFor) { payout in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(payout.eventName)
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundStyle(DesignSystem.Colors.gray900)
                            Text("\(payout.recipient) · \(payout.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundStyle(DesignSystem.Colors.gray500)
                        }
                        Spacer()
                        Text(EventFees.currencyString(payout.amountCents))
                            .font(DesignSystem.Typography.labelLarge)
                            .foregroundStyle(DesignSystem.Colors.gray900)
                        if payout.status == .pending {
                            Button("Mark Paid") {
                                payout.statusRaw = PayoutStatus.paid.rawValue
                                try? context.save()
                            }
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundStyle(DesignSystem.Colors.mintAccent)
                        } else {
                            Text("Paid")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundStyle(DesignSystem.Colors.gray500)
                        }
                    }
                }
            }
            if pendingPayoutCents > 0 {
                Divider().overlay(DesignSystem.Colors.glassBorder)
                Button {
                    recordPayouts()
                } label: {
                    Label("Record payout of \(EventFees.currencyString(pendingPayoutCents))", systemImage: "paperplane.fill")
                        .font(DesignSystem.Typography.labelLarge)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                Text("Logs an internal payout entry for each event equal to its collected entry fees. This is a manual record — it does not transfer money in-app.")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var perEventCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Your events", systemImage: "chart.bar.xaxis")
                .font(DesignSystem.Typography.labelLarge)
                .foregroundStyle(DesignSystem.Colors.gray900)
            if !owned.isEmpty {
                ShareLink(item: settlementCSVURL(), preview: SharePreview("vantage-settlement.csv")) {
                    Label("Export settlement CSV", systemImage: "square.and.arrow.up")
                        .font(DesignSystem.Typography.labelLarge)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            ForEach(owned) { event in
                NavigationLink {
                    EventDetailView(event: event)
                } label: {
                    eventRow(event)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func eventRow(_ event: Event) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.name.isEmpty ? "Untitled event" : event.name)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.gray900)
                Text("\(EventManager.purchasedRegistrations(event).count) paid · \(EventFees.currencyString(EventManager.entryCollectedCents(event))) collected")
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.gray500)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    private func recordPayouts() {
        for event in owned {
            let entry = EventManager.entryCollectedCents(event)
            if entry > 0 {
                EventManager.recordPayout(event: event, amountCents: entry, recipient: myName, context: context)
            }
        }
        toast = "Logged payout entries. Apple holds the money — you pay creators manually outside the app."
    }

    // MARK: - Settlement CSV (Phase 8)

    private var settlementRows: [SettlementRow] {
        owned.flatMap { event -> [SettlementRow] in
            var rows: [SettlementRow] = []
            for pair in EventManager.purchasedRegistrations(event) {
                let registration = pair.registration
                let record = pair.record
                if record.entryCents > 0 {
                    rows.append(SettlementRow(
                        date: registration.joinedAt,
                        eventToken: event.shareToken,
                        eventName: event.name,
                        kind: "entry",
                        playerName: registration.playerName,
                        amountCents: record.entryCents,
                        transactionID: record.appleTransactionID,
                        status: record.status.rawValue
                    ))
                }
                if record.feeCents > 0 {
                    rows.append(SettlementRow(
                        date: registration.joinedAt,
                        eventToken: event.shareToken,
                        eventName: event.name,
                        kind: "platform_fee",
                        playerName: registration.playerName,
                        amountCents: record.feeCents,
                        transactionID: record.appleTransactionID,
                        status: record.status.rawValue
                    ))
                }
            }
            for payout in payouts where payout.eventToken == event.shareToken {
                rows.append(SettlementRow(
                    date: payout.createdAt,
                    eventToken: payout.eventToken,
                    eventName: payout.eventName,
                    kind: "payout",
                    playerName: payout.recipient,
                    amountCents: payout.amountCents,
                    transactionID: "payout-\(payout.persistentModelID.hashValue)",
                    status: payout.status.rawValue
                ))
            }
            return rows
        }
    }

    private func settlementCSVURL() -> URL {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("vantage-settlement.csv")
        if let data = EventSettlementCSV.build(rows: settlementRows).data(using: .utf8) {
            try? data.write(to: file)
        }
        return file
    }
}

private struct statTile: View {
    let title: String
    let value: String
    let icon: String
    var highlight = false

    init(_ title: String, _ value: String, icon: String, highlight: Bool = false) {
        self.title = title
        self.value = value
        self.icon = icon
        self.highlight = highlight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Label(title, systemImage: icon)
                .font(DesignSystem.Typography.captionSmall)
                .foregroundStyle(highlight ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.gray500)
            Text(value)
                .font(DesignSystem.Typography.headlineMedium)
                .foregroundStyle(highlight ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.gray900)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.courtMid.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }
}

// MARK: - Settings integration (Purchase & Payments)

struct PurchasesSection: View {
    @Environment(\.modelContext) private var context
    @State private var restoreResult: String?
    @State private var isRestoring = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            if isRestoring {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ProgressView()
                    Text("Checking your App Store purchases…")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.gray500)
                }
            } else {
                Button {
                    restore()
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.gray900)
                }
            }
            Button {
                PaymentStore.openAppleRefundPage()
            } label: {
                Label("Request a Refund (Report a Problem)", systemImage: "arrow.uturn.backward.circle")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            }
            if let restoreResult {
                Text(restoreResult)
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func restore() {
        isRestoring = true
        restoreResult = nil
        Task {
            let count = await PaymentStore.shared.restorePurchases(context: context)
            restoreResult = count == 0
                ? "No matching App Store purchases found on this device."
                : "Restored \(count) purchase\(count == 1 ? "" : "s")."
            isRestoring = false
        }
    }
}