# Vantage (formerly TennisScore)

iOS + watchOS + Widget app for playing, scoring, and tracking tennis matches,
either against the phone's own engine or in a real phone ↔ watch session.

## What it does

- **Score**: live tennis match scoring — sets, games, points — plus deuce,
  tie-breaks, and best-of-something set lengths.
- **Rivals**: player profiles; add anyone you play against.
- **Tournaments**: single-elimination knockout brackets (seeded or shuffled)
  and round-robin leagues. Scheduled fixtures can be launched into the live
  scorer; knockout results auto-advance the bracket.
- **Stats**: career head-to-head and per-player stats.
- **More**: the overflow hub — **Events** (create/manage events,
  Creator dashboard), **Settings & Profile**.
- **Creator tools**: create player-created events (tournament, league,
  ladder, custom), manage them, and record payouts.
- **Leagues**: round-robin leagues with standings and score sheets.
- **Skill ratings**: Glicko-2 rating system (`RatingsEngine`).
- **Apple Watch companion app**: mirrors matches started on the phone, can
  score independently, and drives a HealthKit workout.
- **Home Screen & Lock Screen widgets**: an active match surfaces as a
  Live Activity; static **Next Match** (small) and **This Week** (medium)
  home-screen widgets and **Next Match** / **Upcoming Event** lock-screen
  accessories show schedule data.
- **Live Activity**: an active match is surfaced as a Live Activity via ActivityKit.

The app is organized into five top-level tabs: **Score**, **Rivals**, **Tournaments**, **Stats**, and **More**. Creator tools and event management live inside **More**, alongside Settings & Profile.

## Screenshots

<!-- Screenshots will be added here. -->

| Screen | Placeholder |
|---|---|
| Score (match scoring) | _todo_ |
| Rivals (player list) | _todo_ |
| Tournaments (bracket) | _todo_ |
| Stats (head-to-head) | _todo_ |
| More (events / creator) | _todo_ |
| Next Match widget (small) | _todo_ |
| This Week widget (medium) | _todo_ |
| Next Match lock-screen widget | _todo_ |
| Upcoming Event lock-screen widget | _todo_ |

## Platform requirements

- iOS 26.5+ (main app + Widget extension)
- watchOS 26.5+ (Watch app)
- Built with **Xcode 26.6** (`LastUpgradeCheck = 2660`), Swift concurrency on.
- Simulator targets use iOS 26.5 runtimes.

## Project structure

Three targets in `TennisScore.xcodeproj`:

- **TennisScore** — the iOS app.
- **TennisScoreWatch Watch App** — the watchOS companion.
- **TennisScoreWidgetExtension** — home-screen widget, Live Activity, and
  widget control.

This project uses **Xcode 16+ synchronized folder groups** (a
`PBXFileSystemSynchronizedRootGroup`; project `objectVersion = 77`), not
hand-maintained file references, for the three source folders:

- `TennisScore/` → iOS app target. **To add a source file, just drop it into
  this folder — no `.pbxproj` edit needed.** Tournament code lives in
  `TennisScore/Tournaments/` (`DrawEngine`, `TournamentManager`,
  `TournamentModels`, `TournamentView`, `TournamentBracketView`).
- `TennisScoreWatch Watch App/` → Watch target (auto-includes new files the
  same way).
- `TennisScoreWidget/` → Widget target.

A few shared models sit at the repo root (`Player.swift`, `Models.swift`,
`TennisEngine.swift`, `Theme.swift`, …) and are referenced by more than one
target via explicit file references. `Player.swift` in particular is shared
between iOS and watchOS.

## Build / run

1. `open TennisScore.xcodeproj`
2. Select the **TennisScore** scheme and a destination (e.g. an iOS 26.5
   simulator).
3. Run (⌘R). The watch app + widget build through the same scheme.

From the CLI:

```sh
xcodebuild -project TennisScore.xcodeproj -scheme TennisScore \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

## Current feature list

- **Score** — full tennis scoring engine (`TennisEngine`), served/set/game UI.
- **Rivals** — player list + profile, `isCurrentUser` "Me" highlighting.
- **Tournaments** — knockout + round robin creation, live bracket, round-robin standings, launch-into-scorer and auto-advance.
- **Stats** — head-to-head and player stats.
- **More** — overflow hub containing **Events** (create/manage events), **Creator** dashboard, and **Settings & Profile**.
- **Leagues** — round-robin leagues with standings and score sheets.
- **Settings** — app options (set length, tie-break defaults, etc.).
- **Watch** — game state over the phone ↔ watch bridge, HealthKit workouts.
- **Widgets / Live Activity** — `ActivityManager` + `MatchAttributes` power a Live Activity; `NextMatchWidget`, `ThisWeekWidget`, `NextMatchLockWidget`, and `UpcomingEventLockWidget` provide Next Match (small / lock-screen), This Week (medium), and Upcoming Event (lock-screen) widgets via `WidgetKit` + shared `WidgetKitHelper` defaults.

## Known limitations

- The tournament bracket UI works but is due for a clarity pass — round labels,
  per-match status, and overall tournament progress are not clearly surfaced
  in the current `TournamentBracketView` rendering.