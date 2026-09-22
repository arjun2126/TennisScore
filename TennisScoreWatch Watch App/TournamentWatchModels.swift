//
//  TournamentWatchModels.swift
//  Vantage Watch
//
//  Created by Arjun Subramanya on 2026-09-21.
//
//  WATCH-ONLY compile-time mirror of the iOS `Tournament` model.
//
//  `Player.swift` is compiled into BOTH targets, and its `inTournaments`
//  relationship must be unconditional (a property hidden behind any `#if`
//  compiler guard is silently omitted from SwiftData's `@Model` schema metadata
//  in the current toolchain, which fatals at launch on iOS). The watch therefore
//  needs a `Tournament` type to type-check the shared `Player` class.
//
//  This mirror intentionally exposes only the schema surface the shared models
//  reference. It is NEVER included in the watch's `.modelContainer(...)` list
//  (`VantageWatchApp`), so it is never persisted or instantiated on device.
//  The real tournament feature lives in `TennisScore/Tournaments/`, which is an
//  iOS-only synchronized group.

import Foundation
import SwiftData

@Model
final class Tournament {
    var name: String
    var dateCreated: Date

    init(name: String) {
        self.name = name
        self.dateCreated = .now
    }
}