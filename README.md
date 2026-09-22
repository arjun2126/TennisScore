# Vantage (formerly TennisScore)

iOS + watchOS + Widget app for playing, scoring, and tracking tennis matches,
either against the phone's own engine or in a real phone ↔ watch session.

## What it does

- **Score**: live tennis match scoring — sets, games, points — plus deuce,
  tie-breaks, and best-of-something set lengths.
- **History**: every completed match, filterable, with a detail view showing
  players, the score line, and sharing/export of the result.
- **Stats**: career head-to-head and per-player stats.
- **Rivals**: player profiles; add anyone you play against.
- **Profile**: the current user's identity (the "Me" player shown in orange
  throughout the app).
- **Tournaments**: single-elimination knockout brackets (seeded or shuffled)
  and round-robin leagues. Scheduled fixtures can be launched into the live
  scorer; knockout results auto-advance the bracket.
- **Apple Watch companion app**: mirrors matches started on the phone, can
  score independently, and drives a HealthKit workout.
- **Home-screen widget + Live Activity**: an active match is surfaced as a
  Live Activity / widget via ActivityKit.

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
- **History** — completed matches list + detail, PDF/export via `ExportPDF`.
- **Stats** — head-to-head and player stats.
- **Rivals** — player list + profile, `isCurrentUser` "Me" highlighting.
- **Profile** — onboarding + profile setup flow gated by `UserSessionManager`.
- **Tournaments** — knockout + round robin creation, live bracket, round-robin
  standings, launch-into-scorer and auto-advance.
- **Settings** — app options (set length, tie-break defaults, etc.).
- **Watch** — game state over the phone ⇆ watch bridge, HealthKit workouts.
- **Widget/Live Activity** — `ActivityManager` + `MatchAttributes` power a
  Live Activity for the active match.

## Known limitations

- The tournament bracket UI works but is due for a clarity pass — round labels,
  per-match status, and overall tournament progress are not clearly surfaced
  in the current `TournamentBracketView` rendering.