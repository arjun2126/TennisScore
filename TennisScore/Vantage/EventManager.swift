import Foundation
import SwiftData

// MARK: - Pure logic (unit-testable, no SwiftData)

enum EventFees {
    /// Convenience fee for an entry. Percent mode applies to the entry fee;
    /// flat mode is dollars per player. Rounds to the nearest cent.
    static func convenienceFeeCents(entryCents: Int64, mode: EventFeeMode, percent: Double, flatCents: Int64) -> Int64 {
        switch mode {
        case .flat:
            return flatCents
        case .percent:
            return Int64((Double(entryCents) * percent / 100.0).rounded())
        }
    }

    static func totalCents(entryCents: Int64, feeCents: Int64) -> Int64 {
        entryCents + feeCents
    }

    static func cents(fromDollars dollars: String) -> Int64 {
        let cleaned = dollars
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned), value.isFinite, value >= 0 else { return 0 }
        return Int64((value * 100).rounded())
    }

    static func currencyString(_ cents: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: Double(cents) / 100.0)) ?? String(format: "$%.2f", Double(cents) / 100.0)
    }
}

/// Publish-time governance. Encodes: public events 18+ only; minors (13–17)
/// allowed only in PRIVATE events AND only with the creator's parental-consent
/// attestation. Returns a human-readable failure reason or nil if publishable.
enum EventGate {
    static func publishError(_ event: Event) -> String? {
        if event.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Give your event a name before publishing."
        }
        if event.maxPlayers < 2 {
            return "Events need a capacity of at least 2 players."
        }
        if event.endDate < event.startDate {
            return "The end date must be after the start date."
        }
        if event.visibility == .publicEvent, event.ageMin < 18 {
            return "Public events are restricted to players 18 and older."
        }
        if event.isMinorSpace, !event.attestMinorConsent {
            return "You must confirm parental consent for all minors before publishing."
        }
        if event.isMinorSpace, event.visibility == .publicEvent {
            return "Events with players under 18 must be private."
        }
        return nil
    }
}

enum EventLink {
    static let scheme = "vantage"

    static func url(shareToken: String) -> URL {
        URL(string: "\(scheme)://event/\(shareToken)")!
    }

    /// Extracts the share token from `vantage://event/<token>`. Tolerant to
    /// trailing slashes and query noise; nil when the URL isn't an event link.
    static func token(from url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == "event" else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard let last = components.last, !last.isEmpty else { return nil }
        return last
    }
}

// MARK: - Store-facing helpers

@MainActor
enum EventManager {
    /// Stamps ownership from the current on-device player when available.
    static func ownerStamp(context: ModelContext) -> String {
        Player.currentUser(in: context)?.name ?? "Me"
    }

    static func publish(_ event: Event, context: ModelContext) -> String? {
        if let error = EventGate.publishError(event) { return error }
        event.statusRaw = EventStatus.published.rawValue
        try? context.save()
        return nil
    }

    static func unpublish(_ event: Event, context: ModelContext) {
        event.statusRaw = EventStatus.draft.rawValue
        try? context.save()
    }

    static func cancel(_ event: Event, context: ModelContext) {
        event.statusRaw = EventStatus.cancelled.rawValue
        try? context.save()
    }

    static func apply(_ config: EventDraftConfig, to event: Event, context: ModelContext) {
        event.name = config.name
        event.summary = config.summary
        event.eventTypeRaw = config.eventType.rawValue
        event.rulesDetail = config.formatPreset.title
        event.maxPlayers = config.maxPlayers
        event.startDate = config.startDate
        event.endDate = config.endDate
        event.regDeadline = config.regDeadline
        event.locationLabel = config.location
        event.latitude = config.latitude
        event.longitude = config.longitude
        event.skillMin = config.skillMin
        event.skillMax = config.skillMax
        event.ageMin = config.ageMin
        event.ageMax = config.ageMax
        event.ratingOn = config.ratingOn
        event.entryFeeCents = EventFees.cents(fromDollars: config.entryFeeDollars)
        event.feeModeRaw = config.feeMode.rawValue
        event.convenienceFeePercent = config.feePercent
        event.convenienceFeeFlatCents = EventFees.cents(fromDollars: config.feeFlatDollars)
        event.visibilityRaw = config.visibility.rawValue
        event.attestMinorConsent = config.attestMinorConsent
        try? context.save()
    }

    // MARK: Roster & joining

    static func currentPlayerName(context: ModelContext) -> String {
        ownerStamp(context: context)
    }

    static func isOwner(_ event: Event, name: String?) -> Bool {
        guard let name, !name.isEmpty else { return false }
        return event.createdByName == name || event.createdByName.isEmpty
    }

    static func confirmedCount(_ event: Event) -> Int {
        event.registrations.filter { $0.status == .confirmed }.count
    }

    static func waitlistCount(_ event: Event) -> Int {
        event.registrations.filter { $0.status == .waitlisted }.count
    }

    static func isFull(_ event: Event) -> Bool {
        confirmedCount(event) >= event.maxPlayers
    }

    /// Pure decision: does a spot open at the current confirmed count?
    nonisolated static func registrationStatusFor(confirmed: Int, maxPlayers: Int) -> EventRegistrationStatus {
        confirmed < maxPlayers ? .confirmed : .waitlisted
    }

    /// Returns the live registration for `name` (confirmed or waitlisted), if any.
    static func registration(_ event: Event, name: String) -> EventRegistration? {
        event.registrations.first { $0.playerName == name && $0.status != .cancelled && $0.status != .refunded }
    }

    static func joinedRoster(_ event: Event) -> [EventRegistration] {
        event.registrations
            .filter { $0.status == .confirmed || $0.status == .waitlisted }
            .sorted { $0.joinedAt < $1.joinedAt }
    }

    /// Joins (or waitlists) the current player. Mock in Phase 3; Phase 4 gates
    /// entry on a verified IAP purchase. Schedules a start reminder.
    @discardableResult
    static func join(_ event: Event, name: String, context: ModelContext) -> EventRegistrationStatus {
        defer { try? context.save() }
        if let existing = registration(event, name: name) {
            return existing.status
        }
        let spotOpen = registrationStatusFor(confirmed: confirmedCount(event), maxPlayers: event.maxPlayers) == .confirmed
        let status: EventRegistrationStatus = spotOpen ? .confirmed : .waitlisted
        let reg = EventRegistration(
            playerName: name,
            player: Player.currentUser(in: context),
            status: status,
            event: event
        )
        context.insert(reg)
        NotificationManager.shared.scheduleEventReminder(
            id: "event-start-\(event.shareToken)",
            date: event.startDate.addingTimeInterval(-3600),
            title: "\(event.name) starts soon 🎾",
            body: spotOpen ? "Your spot is confirmed. See you on court!" : "You're on the waitlist — keep an eye on your spot."
        )
        return status
    }

    static func leave(_ event: Event, name: String, context: ModelContext) {
        if let reg = registration(event, name: name) {
            reg.statusRaw = EventRegistrationStatus.cancelled.rawValue
            try? context.save()
        }
    }

    static func cancelRegistration(_ reg: EventRegistration, context: ModelContext) {
        reg.statusRaw = EventRegistrationStatus.cancelled.rawValue
        try? context.save()
    }

    static func report(_ event: Event, reason: String, name: String, context: ModelContext) {
        let report = EventReport(eventToken: event.shareToken, eventName: event.name, reason: reason, reporterName: name)
        context.insert(report)
        try? context.save()
    }
}

// MARK: - Proximity (pure, haversine)

enum EventProximity {
    static func distanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return r * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    static func distanceKm(from lat: Double?, _ lon: Double?, to event: Event) -> Double? {
        guard let lat, let lon, let elat = event.latitude, let elon = event.longitude else { return nil }
        return distanceKm(lat1: lat, lon1: lon, lat2: elat, lon2: elon)
    }
}

// MARK: - Wizard configuration

struct EventDraftConfig {
    var name = ""
    var summary = ""
    var eventType: VantageEventType = .tournament
    var formatPreset: EventFormatPreset = .singleElimination
    var maxPlayers = 8
    var startDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    var endDate = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    var regDeadline = Calendar.current.date(byAdding: .day, value: 6, to: .now) ?? .now
    var location = ""
    var latitude: Double?
    var longitude: Double?
    var skillMin = 1
    var skillMax = 7
    var ageMin = 18
    var ageMax = 99
    var ratingOn = true
    var entryFeeDollars = ""
    var feeMode: EventFeeMode = .percent
    var feePercent = 15.0
    var feeFlatDollars = "3"
    var visibility: EventVisibility = .privateEvent
    var attestMinorConsent = false

    nonisolated init() {}

    /// Loads existing values for editing.
    init(from event: Event) {
        name = event.name
        summary = event.summary
        eventType = event.eventType
        formatPreset = EventFormatPreset(rawValue: event.rulesDetail)
            ?? (event.rulesDetail.isEmpty ? (EventFormatPreset.options(for: event.eventType).first ?? .customRules) : .customRules)
        maxPlayers = event.maxPlayers
        startDate = event.startDate
        endDate = event.endDate
        regDeadline = event.regDeadline
        location = event.locationLabel
        latitude = event.latitude
        longitude = event.longitude
        skillMin = event.skillMin
        skillMax = event.skillMax
        ageMin = event.ageMin
        ageMax = event.ageMax
        ratingOn = event.ratingOn
        entryFeeDollars = event.entryFeeCents > 0 ? EventFees.currencyString(event.entryFeeCents) : ""
        feeMode = event.feeMode
        feePercent = event.convenienceFeePercent
        feeFlatDollars = event.convenienceFeeFlatCents > 0 ? EventFees.currencyString(event.convenienceFeeFlatCents) : ""
        visibility = event.visibility
        attestMinorConsent = event.attestMinorConsent
    }

    var entryCents: Int64 { EventFees.cents(fromDollars: entryFeeDollars) }
    var isMinorSpace: Bool { ageMin < 18 }
    var feeCents: Int64 {
        EventFees.convenienceFeeCents(entryCents: entryCents, mode: feeMode, percent: feePercent, flatCents: EventFees.cents(fromDollars: feeFlatDollars))
    }
    var totalCents: Int64 { entryCents + feeCents }

    func validationMessage(forStep step: Int) -> String? {
        switch step {
        case 1:
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Name your event." }
            if maxPlayers < 2 { return "Capacity must be at least 2." }
            if regDeadline > startDate { return "Registration deadline must be before the start date." }
            if endDate < startDate { return "End date must be after the start date." }
            return nil
        case 2:
            if skillMin > skillMax { return "Min skill can't exceed max skill." }
            if ageMin > ageMax { return "Min age can't exceed max age." }
            if ageMin < 13 { return "Minimum age is 13." }
            return nil
        case 3:
            return nil
        default:
            return nil
        }
    }
}