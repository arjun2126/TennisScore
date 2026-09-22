import Foundation

// MARK: - Singles rating (Glicko-2, pure)

// This file is compiled by the iOS app only (it lives under `TennisScore/` in
// the D101 exception set, and is NOT in the watch target). `Player` also
// compiles the watch app, so its rating scalars are `#if !os(watchOS)`-gated.
// RatingsManager intentionally stays iOS-only because `EventMatch` never
// crosses the watch bridge.

/// A Glicko-2 rating triplet: `rating` (R), `deviation` (RD), `volatility` (σ).

enum RatingBand: String, Codable, CaseIterable {
    case junior
    case adult

    var label: String {
        switch self {
        case .junior: return "Junior"
        case .adult: return "Adult"
        }
    }
}

/// A Glicko-2 rating triplet: `rating` (R), `deviation` (RD), `volatility` (σ).
/// Pure value type — the `Player` model persists it as three `Double` scalars so
/// the watch mirror and lightweight migration stay trivially safe.
struct GlickoRating: Equatable {
    var rating: Double = RatingsEngine.initialRating
    var deviation: Double = RatingsEngine.initialDeviation
    var volatility: Double = RatingsEngine.initialVolatility

    /// Rating displayed when provisional; omitted vs a confirmed rating.
    var isProvisional: Bool { ratedGames < RatingsEngine.provisionalGames }

    /// "RD < 100 → isolated" scale for display (higher is more decisive).
    var confidence: String {
        switch deviation {
        case ..<50: return "A"
        case ..<100: return "B"
        case ..<200: return "C"
        default: return "D"
        }
    }

    var ratedGames: Int = 0
}

/// One rated encounter in the current rating period. `outcome`: 1 = win,
/// 0.5 = draw, 0 = loss.
struct RatedGame: Equatable {
    var opponentRating: Double
    var opponentDeviation: Double
    var outcome: Double
}

struct RatingUpdate: Equatable {
    var rating: GlickoRating
    var appliedDelta: Double
}

nonisolated enum RatingsEngine {
    static let initialRating = 1500.0
    static let initialDeviation = 350.0
    static let initialVolatility = 0.06
    static let provisionalGames = 8
    /// System constant τ (paper default 0.5; raises = more rating movement).
    static let systemConstant = 0.5
    /// Scale from base rating to Glicko-2 µ.
    private static let scale = 173.7178
    private static let epsilon = 1e-6

    /// g(φ) in µ-scale.
    nonisolated static func g(_ deviation: Double) -> Double {
        let phi = deviation / scale
        return 1 / sqrt(1 + 3 * phi * phi / (Double.pi * Double.pi))
    }

    /// Expected score µ, µj (both in base-rating space; formula uses their
    /// difference scaled).
    private static func expected(_ mu: Double, _ muJ: Double, _ phiJ: Double) -> Double {
        let diff = (mu - muJ) / scale
        let denom = 1 + exp(-g(phiJ) * diff)
        return 1 / denom
    }

    /// Batch update over a rating period (all games simultaneous — players
    /// faced during one event update together). Reference sequence from the
    /// Glicko-2 paper Example converges to r=1464.06, RD=151.52, σ=0.05999.
    nonisolated static func update(_ rating: GlickoRating, games: [RatedGame]) -> RatingUpdate {
        guard !games.isEmpty else { return RatingUpdate(rating: rating, appliedDelta: 0) }

        let mu = rating.rating
        let phi = rating.deviation / scale
        let sigma = rating.volatility

        // Summations over the period.
        var varianceSum = 0.0
        var deltaSum = 0.0
        for game in games {
            let expScore = expected(mu, game.opponentRating, game.opponentDeviation)
            let g = g(game.opponentDeviation)
            varianceSum += g * g * expScore * (1 - expScore)
            deltaSum += g * (game.outcome - expScore)
        }
        guard varianceSum > 0 else {
            // No information (zero variance) — no rating change.
            return RatingUpdate(rating: rating, appliedDelta: 0)
        }
        let v = 1 / varianceSum
        let delta = deltaSum * v

        // Volatility update (inner iterative search for the new σ).
        let phi2 = phi * phi
        let alpha = log(sigma * sigma)
        let tau2 = systemConstant * systemConstant
        func f(_ x: Double) -> Double {
            let ex = exp(x)
            let denomBase = phi2 + v + ex
            return ex * (delta * delta - phi2 - v - ex) / (2 * denomBase * denomBase)
                - (x - alpha) / tau2
        }
        var a = alpha
        var b = delta * delta > phi2 + v ? log(delta * delta - phi2 - v) : alpha - tau2
        var fA = f(a)
        var fB = f(b)
        var guardCount = 0
        while abs(b - a) > epsilon && guardCount < 100 {
            guardCount += 1
            let c = a + (a - b) * fA / (fB - fA)
            let fC = f(c)
            if fC * fB < 0 {
                a = b
                fA = fB
            } else {
                fA /= 2
            }
            b = c
            fB = fC
        }
        let newSigma = exp(a / 2)

        // New deviation then rating (µ → base-rating points via `scale`).
        let phiStar2 = phi2 + newSigma * newSigma
        let newPhi = 1 / sqrt(1 / phiStar2 + 1 / v)
        var muSum = 0.0
        for game in games {
            let expScore = expected(mu, game.opponentRating, game.opponentDeviation)
            muSum += g(game.opponentDeviation) * (game.outcome - expScore)
        }
        let newMuPoints = rating.rating + (newPhi * newPhi * muSum) * scale

        let newRating = GlickoRating(
            rating: newMuPoints,
            deviation: newPhi * scale,
            volatility: newSigma,
            ratedGames: rating.ratedGames + games.count
        )
        return RatingUpdate(rating: newRating, appliedDelta: newRating.rating - rating.rating)
    }

    /// Single-match convenience: a win and a loss in one update.
    nonisolated static func win(_ winner: GlickoRating, loser: GlickoRating) -> RatingUpdate {
        update(winner, games: [RatedGame(
            opponentRating: loser.rating,
            opponentDeviation: loser.deviation,
            outcome: 1
        )])
    }
}

// MARK: - Ratings manager (applies Glicko updates on rated event results)

import SwiftData

enum RatingsManager {
    /// Applies a rated event result to the device's player rows for both names
    /// (identity is name-stamped, matching registrations). Only touches players
    /// that exist locally; the current user is always the interesting one.
    @MainActor
    static func recordRatedResult(match: EventMatch, event: Event, context: ModelContext) {
        guard event.ratingOn, let winner = match.winnerName else { return }
        let winnerName = winner
        let loserName = winnerName == match.playerAName ? match.playerBName : match.playerAName
        guard !loserName.isEmpty else { return }

        guard let winnerPlayer = player(named: winnerName, context: context),
              let loserPlayer = player(named: loserName, context: context) else {
            return
        }
        let band = ratingBand(for: event)
        winnerPlayer.ratingBandRaw = band.rawValue
        loserPlayer.ratingBandRaw = band.rawValue

        let winnerUpdate = RatingsEngine.win(
            winnerPlayer.singlesRating,
            loser: loserPlayer.singlesRating
        )
        // Loss update for the loser uses the mirror win the other way.
        let loserUpdate = RatingsEngine.update(
            loserPlayer.singlesRating,
            games: [RatedGame(
                opponentRating: winnerPlayer.singlesRating.rating,
                opponentDeviation: winnerPlayer.singlesRating.deviation,
                outcome: 0
            )]
        )
        winnerPlayer.applySinglesRating(winnerUpdate.rating)
        loserPlayer.applySinglesRating(loserUpdate.rating)
        try? context.save()
    }

    @MainActor
    static func ratingBand(for event: Event) -> RatingBand {
        (event.ageMax < 18) ? .junior : .adult
    }

    @MainActor
    private static func player(named name: String, context: ModelContext) -> Player? {
        let descriptor = FetchDescriptor<Player>(predicate: #Predicate { $0.name == name })
        return (try? context.fetch(descriptor))?.first
    }
}

extension Player {
    /// Bundled Glicko-2 singles rating (stored as three scalars + game count).
    var singlesRating: GlickoRating {
        GlickoRating(
            rating: ratingSingleR,
            deviation: ratingSingleRD,
            volatility: ratingSingleVol,
            ratedGames: ratingRatedGames
        )
    }

    func applySinglesRating(_ rating: GlickoRating) {
        ratingSingleR = rating.rating
        ratingSingleRD = rating.deviation
        ratingSingleVol = rating.volatility
        ratingRatedGames = rating.ratedGames
    }

    var ratingBand: RatingBand? {
        RatingBand(rawValue: ratingBandRaw)
    }
}