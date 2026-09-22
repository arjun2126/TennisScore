import Foundation
import SwiftData

// MARK: - Event value types

enum VantageEventType: String, Codable, CaseIterable, Identifiable {
    case tournament
    case league
    case ladder
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tournament: return "Tournament"
        case .league: return "League"
        case .ladder: return "Ladder"
        case .custom: return "Custom Event"
        }
    }

    var symbol: String {
        switch self {
        case .tournament: return "trophy.fill"
        case .league: return "list.number"
        case .ladder: return "chart.bar.xaxis"
        case .custom: return "star.circle.fill"
        }
    }
}

enum EventVisibility: String, Codable, CaseIterable, Identifiable {
    case privateEvent
    case publicEvent

    var id: String { rawValue }
    var title: String { self == .privateEvent ? "Private" : "Public" }
}

enum EventStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case published
    case cancelled
    case completed

    var id: String { rawValue }
    var title: String {
        switch self {
        case .draft: return "Draft"
        case .published: return "Published"
        case .cancelled: return "Cancelled"
        case .completed: return "Completed"
        }
    }
}

enum EventFeeMode: String, Codable, CaseIterable, Identifiable {
    case percent
    case flat

    var id: String { rawValue }
    var title: String { self == .percent ? "Percentage" : "Flat" }
}

/// Format presets offered in the create wizard, scoped per event type.
enum EventFormatPreset: String, Codable, CaseIterable, Identifiable {
    case singleElimination
    case roundRobinFull
    case roundRobinDoubles
    case groupThenKnockout
    case doubleRoundRobin
    case kingOfCourt
    case challengeLadder
    case customRules

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singleElimination: return "Single Elimination Knockout"
        case .roundRobinFull: return "Full Round Robin"
        case .roundRobinDoubles: return "Round Robin (Doubles)"
        case .groupThenKnockout: return "Group Stage + Knockout"
        case .doubleRoundRobin: return "Double Round Robin"
        case .kingOfCourt: return "King of the Court"
        case .challengeLadder: return "Challenge Ladder"
        case .customRules: return "Custom Rules"
        }
    }

    static func options(for type: VantageEventType) -> [EventFormatPreset] {
        switch type {
        case .tournament: return [.singleElimination, .groupThenKnockout, .roundRobinFull, .customRules]
        case .league: return [.roundRobinFull, .doubleRoundRobin, .roundRobinDoubles, .kingOfCourt, .customRules]
        case .ladder: return [.challengeLadder, .customRules]
        case .custom: return [.customRules]
        }
    }
}

// MARK: - Event model

/// A user-created event (tournament / league / ladder / custom) that players
/// can join. Metadata-only in Phase 2 — registrations, payments and matches
/// attach to it in later phases.
@Model
final class Event {
    // Identity + ownership
    @Attribute(.unique) var shareToken: String
    var createdAt: Date
    var createdByName: String

    // Core details
    var name: String
    var summary: String
    var eventTypeRaw: String
    var rulesDetail: String
    var maxPlayers: Int
    var startDate: Date
    var endDate: Date
    var regDeadline: Date
    var locationLabel: String
    var latitude: Double?
    var longitude: Double?

    // Eligibility filters
    var skillMin: Int
    var skillMax: Int
    var ageMin: Int
    var ageMax: Int
    var ratingOn: Bool

    // Money (display-only until Phase 4; never settled outside IAP)
    var entryFeeCents: Int64
    var feeModeRaw: String
    var convenienceFeePercent: Double
    var convenienceFeeFlatCents: Int64

    // Governance
    var visibilityRaw: String
    var statusRaw: String
    var attestMinorConsent: Bool

    /// Joined (and waitlisted) players. Cascade deletes registrations when an
    /// event is removed. Inverse lives here, not on Player (watch mirror).
    @Relationship(deleteRule: .cascade, inverse: \EventRegistration.event)
    var registrations: [EventRegistration] = []

    init(
        name: String = "",
        summary: String = "",
        eventType: VantageEventType = .tournament,
        rulesDetail: String = "",
        maxPlayers: Int = 8,
        startDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now,
        endDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now,
        regDeadline: Date = Calendar.current.date(byAdding: .day, value: 6, to: .now) ?? .now,
        locationLabel: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        skillMin: Int = 1,
        skillMax: Int = 7,
        ageMin: Int = 18,
        ageMax: Int = 99,
        ratingOn: Bool = true,
        entryFeeCents: Int64 = 0,
        feeMode: EventFeeMode = .percent,
        convenienceFeePercent: Double = 15,
        convenienceFeeFlatCents: Int64 = 300,
        visibility: EventVisibility = .privateEvent,
        attestMinorConsent: Bool = false,
        createdByName: String = ""
    ) {
        self.shareToken = UUID().uuidString
        self.createdAt = .now
        self.createdByName = createdByName
        self.name = name
        self.summary = summary
        self.eventTypeRaw = eventType.rawValue
        self.rulesDetail = rulesDetail
        self.maxPlayers = maxPlayers
        self.startDate = startDate
        self.endDate = endDate
        self.regDeadline = regDeadline
        self.locationLabel = locationLabel
        self.latitude = latitude
        self.longitude = longitude
        self.skillMin = skillMin
        self.skillMax = skillMax
        self.ageMin = ageMin
        self.ageMax = ageMax
        self.ratingOn = ratingOn
        self.entryFeeCents = entryFeeCents
        self.feeModeRaw = feeMode.rawValue
        self.convenienceFeePercent = convenienceFeePercent
        self.convenienceFeeFlatCents = convenienceFeeFlatCents
        self.visibilityRaw = visibility.rawValue
        self.statusRaw = EventStatus.draft.rawValue
        self.attestMinorConsent = attestMinorConsent
    }

    // MARK: Derived display properties

    var eventType: VantageEventType { VantageEventType(rawValue: eventTypeRaw) ?? .custom }
    var visibility: EventVisibility { EventVisibility(rawValue: visibilityRaw) ?? .privateEvent }
    var status: EventStatus { EventStatus(rawValue: statusRaw) ?? .draft }
    var feeMode: EventFeeMode { EventFeeMode(rawValue: feeModeRaw) ?? .percent }

    var convenienceFeeCents: Int64 {
        EventFees.convenienceFeeCents(
            entryCents: entryFeeCents,
            mode: feeMode,
            percent: convenienceFeePercent,
            flatCents: convenienceFeeFlatCents
        )
    }

    var totalCents: Int64 { EventFees.totalCents(entryCents: entryFeeCents, feeCents: convenienceFeeCents) }

    var isMinorSpace: Bool { ageMin < 18 }

    var dateLine: String {
        let f = Date.FormatStyle(date: .abbreviated, time: .omitted)
        return "\(startDate.formatted(f)) → \(endDate.formatted(f))"
    }

    var eligibilityLine: String {
        "Skill \(skillMin)–\(skillMax) · Ages \(ageMin)–\(ageMax)\(ratingOn ? " · Rated" : "")"
    }

    var feeLine: String {
        if entryFeeCents > 0 {
            return "\(EventFees.currencyString(entryFeeCents)) entry + \(EventFees.currencyString(convenienceFeeCents)) fee"
        }
        return "Free entry"
    }
}

// MARK: - Registration & moderation

enum EventRegistrationStatus: String, Codable {
    case pending
    case confirmed
    case waitlisted
    case cancelled
    case refunded
}

enum EventReportStatus: String, Codable {
    case pending
    case resolved
    case dismissed
}

/// A player's spot (or waitlist position) on an event. The `player`
/// relationship is intentionally one-sided (no inverse on `Player`) because
/// `Player.swift` also compiles into the watch target; identity is
/// name-stamped locally. `Event.registrations` owns the cascade inverse.
@Model
final class EventRegistration {
    var playerName: String
    var player: Player?
    var statusRaw: String
    var joinedAt: Date
    var event: Event?
    var paymentRecord: PaymentRecord?

    init(playerName: String, player: Player? = nil, status: EventRegistrationStatus, event: Event? = nil) {
        self.playerName = playerName
        self.player = player
        self.statusRaw = status.rawValue
        self.joinedAt = .now
        self.event = event
    }

    var status: EventRegistrationStatus { EventRegistrationStatus(rawValue: statusRaw) ?? .cancelled }
}

/// UGC moderation prep (Guideline 1.2): public events render a report flow that
/// writes one of these; the admin queue (Phase 8) reviews them.
@Model
final class EventReport {
    var eventToken: String
    var eventName: String
    var reason: String
    var reporterName: String
    var statusRaw: String
    var createdAt: Date

    init(eventToken: String, eventName: String, reason: String, reporterName: String) {
        self.eventToken = eventToken
        self.eventName = eventName
        self.reason = reason
        self.reporterName = reporterName
        self.statusRaw = EventReportStatus.pending.rawValue
        self.createdAt = .now
    }

    var status: EventReportStatus { EventReportStatus(rawValue: statusRaw) ?? .pending }
}

enum EventModeration {
    static let reportReasons = [
        "Inappropriate content",
        "Misleading or fake event",
        "Entry fee or payment problem",
        "Harassment or abusive organiser",
        "Something else",
    ]
}