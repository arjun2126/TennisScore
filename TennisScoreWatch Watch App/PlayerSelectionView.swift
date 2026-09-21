import SwiftUI
import WatchKit

/// First-class companion: pick both players, choose who serves, and start —
/// entirely on the wrist. No iPhone redirect.
struct PlayerSelectionView: View {
    @ObservedObject private var bridge = WatchBridge.shared
    @Environment(\.dismiss) private var dismiss

    @State private var p1Name: String? = nil
    @State private var p2Name: String? = nil
    @State private var firstServer = 1
    @State private var isTossing = false
    @State private var tossAngle: Double = 0

    /// playerOne name, playerTwo name, firstServer (1 or 2)
    var onStart: (String, String, Int) -> Void

    private var roster: [String] { bridge.roster }

    private var p1Label: String { p1Name ?? "Player 1" }
    private var p2Label: String { p2Name ?? "Player 2" }

    private var canStart: Bool {
        guard let p1 = p1Name, let p2 = p2Name else { return false }
        return !p1.isEmpty && !p2.isEmpty && p1 != p2
    }

    var body: some View {
        NavigationStack {
            List {
                if roster.isEmpty {
                    Section {
                        Text("No players yet. Open the iPhone app once to sync your Player Book.")
                            .font(.caption)
                            .foregroundStyle(Color.gray500)
                        Button("Retry Sync") {
                            WKInterfaceDevice.current().play(.click)
                            WatchBridge.shared.requestCurrentState()
                        }
                        .font(.footnote)
                        .bold()
                        .foregroundStyle(Color.mintAccent)
                    }
                } else {
                    Section("Player 1") {
                        Picker("Player 1", selection: $p1Name) {
                            Text("Choose…").tag(nil as String?)
                            ForEach(roster, id: \.self) { name in
                                Text(name).tag(name as String?)
                            }
                        }
                        .font(.footnote)
                    }

                    Section("Player 2") {
                        Picker("Player 2", selection: $p2Name) {
                            Text("Choose…").tag(nil as String?)
                            ForEach(roster, id: \.self) { name in
                                Text(name).tag(name as String?)
                            }
                        }
                        .font(.footnote)
                    }

                    Section("Serve") {
                        HStack(spacing: 6) {
                            serveChoiceButton(label: p1Label, server: 1)
                            serveChoiceButton(label: p2Label, server: 2)
                        }
                        .disabled(isTossing)

                        Button(action: tossForServe) {
                            Label(isTossing ? "Tossing…" : "Toss for Serve", systemImage: "arrow.triangle.2.circlepath")
                                .font(.footnote)
                                .bold()
                                .foregroundStyle(Color.mintAccent)
                        }
                        .disabled(isTossing)

                        HStack(spacing: 4) {
                            Image(systemName: "tennisball.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.mintAccent)
                                .rotationEffect(.degrees(tossAngle))
                            Text("\(firstServer == 1 ? p1Label : p2Label) serves")
                                .font(.caption)
                                .bold()
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }

                    Section("Rules") {
                        Text("Best of 3 • Set to 6 • TB to 7")
                            .font(.caption)
                            .foregroundStyle(Color.gray500)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Section {
                        Button(action: startMatch) {
                            Label("Start Match", systemImage: "play.fill")
                                .font(.footnote)
                                .bold()
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(canStart ? Color.mintAccent : Color.gray500.opacity(0.3))
                                .foregroundStyle(canStart ? .black : .white)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canStart)

                        Button("Cancel") { dismiss() }
                            .font(.footnote)
                            .foregroundStyle(Color.gray500)
                    }
                }
            }
            .navigationTitle("New Match")
            .onAppear {
                // Profile-first: Me is always Player 1 when known.
                // Only fills an empty slot — never overwrites a choice.
                if p1Name == nil {
                    let me = bridge.currentUserName
                    if !me.isEmpty {
                        p1Name = me
                    }
                }
            }
        }
    }

    private func serveChoiceButton(label: String, server: Int) -> some View {
        Button(action: {
            WKInterfaceDevice.current().play(.click)
            withAnimation(Animation.springBouncy) {
                firstServer = server
            }
        }) {
            Text(label)
                .font(.footnote)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(firstServer == server ? Color.mintAccent : Color.white.opacity(0.12))
                .foregroundStyle(firstServer == server ? .black : .white)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        }
        .buttonStyle(.plain)
    }

    private func tossForServe() {        guard !isTossing else { return }
        isTossing = true
        WKInterfaceDevice.current().play(.click)
        tossAngle = 0
        withAnimation(.easeInOut(duration: 0.9)) {
            tossAngle += 360 * Double(Int.random(in: 3...5))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(Animation.springBouncy) {
                firstServer = Int.random(in: 1...2)
            }
            WKInterfaceDevice.current().play(.success)
            isTossing = false
        }
    }

    private func startMatch() {
        guard canStart, let p1 = p1Name, let p2 = p2Name else { return }
        WKInterfaceDevice.current().play(.click)
        onStart(p1, p2, firstServer)
    }
}

#Preview {
    PlayerSelectionView(onStart: { _, _, _ in })
}
