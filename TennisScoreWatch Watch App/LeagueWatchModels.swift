//
//  LeagueWatchModels.swift
//  Vantage Watch
//
//  Created by Arjun Subramanya on 2026-09-22.
//
//  WATCH-ONLY compile-time mirror of the iOS `League`/`LeagueMatch` models.
//
//  `Player.swift` is compiled into BOTH targets, and its `leagues` relationship
//  must be unconditional (a property hidden behind any `#if` compiler guard is
//  silently omitted from SwiftData's `@Model` schema metadata in the current
//  toolchain, which fatals at launch on iOS). The watch therefore needs a
//  `League` type to type-check the shared `Player` class.
//
//  This mirror intentionally exposes only the stored schema surface the shared
//  models reference. It is NEVER included in the watch's own `.modelContainer(...)`
//  list (`VantageWatchApp`), so it is never persisted or instantiated on device.
//  The real league feature lives in `TennisScore/LeagueModels.swift`, an
//  iOS-only target.
//
//  Keep the stored property names, types, and relationship delete-rules in sync
//  with the iOS originals (mirror of League/LeagueMatch, keep shape in sync).

import Foundation
import SwiftData

@Model
final class League {
    var name: String
    var dateCreated: Date

    @Relationship(deleteRule: .cascade, inverse: \LeagueMatch.league)
    var matches: [LeagueMatch]

    @Relationship(deleteRule: .nullify, inverse: \Player.leagues)
    var roster: [Player]

    init(name: String, roster: [Player], dateCreated: Date = .now) {
        self.name = name
        self.dateCreated = dateCreated
        self.matches = []
        self.roster = roster
    }
}

@Model
final class LeagueMatch {
    var week: Int
    var position: Int
    var playerOne: Player?
    var playerTwo: Player?
    var winner: Player?
    var setScores: String
    var statusRaw: String

    var league: League?

    init(week: Int, position: Int, playerOne: Player?, playerTwo: Player?) {
        self.week = week
        self.position = position
        self.playerOne = playerOne
        self.playerTwo = playerTwo
        self.winner = nil
        self.setScores = ""
        self.statusRaw = "pending"
    }
}