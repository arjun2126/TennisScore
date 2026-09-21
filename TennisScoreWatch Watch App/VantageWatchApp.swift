//
//  VantageWatchApp.swift
//  Vantage Watch
//
//  Created by Arjun Subramanya on 2026-09-13.
//

import SwiftUI
import SwiftData

@main
struct VantageWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchView()
                .onAppear {
                    // Cold-start handshake from the entry point (WatchView
                    // repeats it with retries; this fires it immediately).
                    WatchBridge.shared.requestCurrentState()
                }
        }
        .modelContainer(for: [Match.self, PointEvent.self, Player.self])
    }
}
