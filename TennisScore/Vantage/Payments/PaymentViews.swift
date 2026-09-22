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
                    summaryCard
                    payoutCard
                    if owned.isEmpty {
                        emptyState
                    } else {
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

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Label("Settlement (Path 1 — manual PayPal)", systemImage: "banknote")
                .font(DesignSystem.Typography.labelLarge)
                .foregroundStyle(DesignSystem.Colors.gray900)
            HStack(spacing: DesignSystem.Spacing.sm) {
                statTile("Entry fees collected", EventFees.currencyString(collectedEntryCents), icon: "dollarsign.circle.fill")
                statTile("Platform fee", EventFees.currencyString(collectedFeeCents), icon: "percent")
            }
            HStack(spacing: DesignSystem.Spacing.sm) {
                statTile("Pending payout", EventFees.currencyString(pendingPayoutCents), icon: "clock.fill", highlight: true)
                statTile("Paid out", EventFees.currencyString(paidOutCents), icon: "checkmark.circle.fill")
            }
            Text("Apple holds all purchase revenue in your developer account. This screen tracks what you owe each creator (their entry-fee share); you pay manually via PayPal. Nothing moves money in-app (Cart-Before-Cat).")
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.gray500)
            if !owned.isEmpty {
                ShareLink(item: settlementCSVURL(), preview: SharePreview("vantage-settlement.csv")) {
                    Label("Export Settlement CSV", systemImage: "square.and.arrow.up")
                        .font(DesignSystem.Typography.labelLarge)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var payoutCard: some View {
        let payoutsFor = payouts.filter { payout in
            owned.contains { event in event.shareToken == payout.eventToken }
        }
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Payout history", systemImage: "list.clipboard")
                .font(DesignSystem.Typography.labelLarge)
                .foregroundStyle(DesignSystem.Colors.gray900)
            if payoutsFor.isEmpty {
                Text("None yet. Use Record Mock Payout once you send money via PayPal.")
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
                    recordMockPayouts()
                } label: {
                    Label("Record Mock Payout of \(EventFees.currencyString(pendingPayoutCents))", systemImage: "paperplane.fill")
                        .font(DesignSystem.Typography.labelLarge)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                Text("Logs a pending payout entry for each event equal to its collected entry fees, as a stand-in for a manual PayPal transfer.")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var perEventCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Per-event breakdown", systemImage: "chart.bar.xaxis")
                .font(DesignSystem.Typography.labelLarge)
                .foregroundStyle(DesignSystem.Colors.gray900)
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

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "banknote")
                .font(.system(size: 44))
                .foregroundStyle(DesignSystem.Colors.mintAccentDim)
            Text("No events yet")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundStyle(DesignSystem.Colors.gray900)
            Text("Create an event with an entry fee, publish it, and paid players will show up here with their fee split.")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundStyle(DesignSystem.Colors.gray500)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DesignSystem.Spacing.xxl)
    }

    private func recordMockPayouts() {
        for event in owned {
            let entry = EventManager.entryCollectedCents(event)
            if entry > 0 {
                EventManager.recordPayout(event: event, amountCents: entry, recipient: myName, context: context)
            }
        }
        toast = "Logged payout entries. Apple holds the money — you send creators via PayPal as normal."
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