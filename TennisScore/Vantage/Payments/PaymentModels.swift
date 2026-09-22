import Foundation
import SwiftData

// MARK: - Fee → product mapping (pure)

enum EventPayments {
    /// Price points registered as products. A purchase's price must equal the
    /// event total exactly; anything else is unrepresentable and blocked at
    /// publish time (Guideline 3.1.1: price shown == price charged).
    static let supportedProductCents: Set<Int64> = [
        1000, 1500, 2000, 2500, 3000, 3500, 4000,
        4500, 5000, 6000, 7000, 8000, 10000,
    ]

    static func productID(forTotalCents cents: Int64) -> String? {
        supportedProductCents.contains(cents) ? "vantage.entry.\(cents)" : nil
    }

    static func totalIsSupported(_ event: Event) -> Bool {
        event.totalCents == 0 || productID(forTotalCents: event.totalCents) != nil
    }

    /// Human label listing price points, for gates and disclaimers.
    static func supportedPriceLine() -> String {
        supportedProductCents.sorted().map { EventFees.currencyString($0) }.joined(separator: ", ")
    }
}

// MARK: - Settlement CSV export (Phase 8, pure)

/// One ledger line for the settlement CSV. `kind`: "entry" (creator-owed
/// entry-fee share), "fee" (platform convenience fee), or "payout" (manual
/// transfer logged for a creator).
struct SettlementRow: Equatable {
    let date: Date
    let eventToken: String
    let eventName: String
    let kind: String
    let playerName: String
    let amountCents: Int64
    let transactionID: String
    let status: String
}

nonisolated enum EventSettlementCSV {
    static let header = "date,event,kind,player,amount_usd,transaction_id,status"

    /// Builds a settlement CSV (Path 1 manual settlement: Apple holds the money,
    /// this file is the creator-owed ledger you reconcile against PayPal).
    /// Pure so the harness can assert exact output.
    static func build(rows: [SettlementRow], date: Date = .now) -> String {
        let lines = [header] + rows.map { row in
            [
                row.date.formatted(.iso8601),
                quote(row.eventName),
                quote(row.kind),
                quote(row.playerName),
                EventFees.dollars(row.amountCents),
                quote(row.transactionID),
                quote(row.status),
            ].joined(separator: ",")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// RFC-4180-ish field quoting: wrap in quotes when the field contains a
    /// comma, quote, or newline; double any embedded quotes.
    static func quote(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

// MARK: - Payment ledger (Phase 4)

enum PaymentStatus: String, Codable {
    case purchased
    case refundRequested
    case refunded
}

enum PayoutStatus: String, Codable {
    case pending
    case paid
}

/// One Apple IAP transaction for an event entry. Proves the purchase, records
/// the fee split (entry -> creator, fee -> platform), and drives refunds.
@Model
final class PaymentRecord {
    var appleTransactionID: String
    var productID: String
    var appAccountToken: String
    var event: Event?
    @Relationship(deleteRule: .cascade, inverse: \EventRegistration.paymentRecord)
    var registration: EventRegistration?
    var totalCents: Int64
    var entryCents: Int64
    var feeCents: Int64
    var statusRaw: String
    var purchasedAt: Date

    init(
        appleTransactionID: String,
        productID: String,
        appAccountToken: String,
        event: Event?,
        registration: EventRegistration?,
        totalCents: Int64,
        entryCents: Int64,
        feeCents: Int64
    ) {
        self.appleTransactionID = appleTransactionID
        self.productID = productID
        self.appAccountToken = appAccountToken
        self.event = event
        self.registration = registration
        self.totalCents = totalCents
        self.entryCents = entryCents
        self.feeCents = feeCents
        self.statusRaw = PaymentStatus.purchased.rawValue
        self.purchasedAt = .now
    }

    var status: PaymentStatus { PaymentStatus(rawValue: statusRaw) ?? .refunded }
}

/// Mock payout ledger entry (Path 1 settlement: manual PayPal by the operator).
@Model
final class PayoutRecord {
    var eventToken: String
    var eventName: String
    var amountCents: Int64
    var recipient: String
    var statusRaw: String
    var createdAt: Date

    init(eventToken: String, eventName: String, amountCents: Int64, recipient: String) {
        self.eventToken = eventToken
        self.eventName = eventName
        self.amountCents = amountCents
        self.recipient = recipient
        self.statusRaw = PayoutStatus.pending.rawValue
        self.createdAt = .now
    }

    var status: PayoutStatus { PayoutStatus(rawValue: statusRaw) ?? .pending }
}