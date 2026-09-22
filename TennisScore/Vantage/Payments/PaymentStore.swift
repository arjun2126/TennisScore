import Foundation
import SwiftData
import StoreKit
import UIKit

// MARK: - StoreKit 2 wrapper

// MARK: - StoreKit 2 wrapper

enum PurchaseOutcome: Equatable {
    case success
    case userCancelled
    case pendingReview
    case unavailable(reason: String)
}

@MainActor
final class PaymentStore {
    static let shared = PaymentStore()

    private var updatesTask: Task<Void, Never>?
    private weak var container: ModelContainer?

    private init() {
        startObservingTransactions()
    }

    /// Attach the app container so transaction listeners can reach the store.
    func attach(container: ModelContainer) {
        self.container = container
    }

    /// The `Product` whose price equals the event's total; nil when the total
    /// isn't a registered price point (checked at publish, so rarely nil).
    func product(for event: Event) async -> Product? {
        guard let id = EventPayments.productID(forTotalCents: event.totalCents) else { return nil }
        let products = (try? await Product.products(for: [id])) ?? []
        return products.first { $0.id == id }
    }

    /// Purchases the event-entry product. On success writes the PaymentRecord,
    /// marks the registration purchased (confirming the spot), and returns.
    func purchase(_ product: Product, for event: Event, registration: EventRegistration, context: ModelContext) async -> PurchaseOutcome {
        do {
            let appAccountToken = UUID()
            let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .unavailable(reason: "StoreKit couldn't verify the transaction.")
                }
                let record = PaymentRecord(
                    appleTransactionID: String(transaction.id),
                    productID: product.id,
                    appAccountToken: appAccountToken.uuidString,
                    event: event,
                    registration: registration,
                    totalCents: event.totalCents,
                    entryCents: event.entryFeeCents,
                    feeCents: event.convenienceFeeCents
                )
                context.insert(record)
                registration.paymentRecord = record
                registration.statusRaw = EventRegistrationStatus.confirmed.rawValue
                try? context.save()
                await transaction.finish()
                return .success
            case .pending:
                return .pendingReview
            case .userCancelled:
                return .userCancelled
            @unknown default:
                return .unavailable(reason: "Unknown purchase result.")
            }
        } catch {
            return .unavailable(reason: error.localizedDescription)
        }
    }

    /// Re-discovers App Store transactions. For event entries this recounts
    /// purchases and revokes earlier refunds; used by Settings' Restore.
    func restorePurchases(context: ModelContext) async -> Int {
        var restored = 0
        for await result in Transaction.all {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID.hasPrefix("vantage.entry."), transaction.revocationDate == nil else { continue }
            if let record = fetchRecord(transactionID: String(transaction.id), context: context) {
                if record.status != .purchased {
                    record.statusRaw = PaymentStatus.purchased.rawValue
                    record.registration?.statusRaw = EventRegistrationStatus.confirmed.rawValue
                    try? context.save()
                }
                restored += 1
            }
        }
        return restored
    }

    /// Opens Apple's Report a Problem page for refunds (Guideline 3.1.1).
    static func openAppleRefundPage() {
        guard let url = URL(string: "https://reportaproblem.apple.com") else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Transaction observation (refund/revocation)

    private func startObservingTransactions() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                switch update {
                case .verified(let transaction):
                    if transaction.revocationDate != nil {
                        await self?.handleRevocation(transaction)
                    }
                case .unverified:
                    break
                }
            }
        }
    }

    private func handleRevocation(_ transaction: Transaction) async {
        guard let container else { return }
        let context = container.mainContext
        if let record = fetchRecord(transactionID: String(transaction.id), context: context) {
            record.statusRaw = PaymentStatus.refunded.rawValue
            record.registration?.statusRaw = EventRegistrationStatus.cancelled.rawValue
            try? context.save()
        }
    }

    private func fetchRecord(transactionID: String, context: ModelContext) -> PaymentRecord? {
        let descriptor = FetchDescriptor<PaymentRecord>(
            predicate: #Predicate { $0.appleTransactionID == transactionID }
        )
        return try? context.fetch(descriptor).first
    }
}