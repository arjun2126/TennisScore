import SwiftUI
import SwiftData

struct MatchSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Player.name) private var allPlayers: [Player]
    
    @Binding var selectedP1: Player?
    @Binding var selectedP2: Player?
    @Binding var configuration: MatchConfiguration
    @Binding var location: String
    
    @State private var newP1Name = ""
    @State private var newP2Name = ""
    @State private var tossResult: String? = nil
    @State private var isTossing = false
    
    let onStart: (Player, Player) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Players").foregroundStyle(.white)) {
                    VStack(alignment: .leading) {
                        Picker("Player 1", selection: $selectedP1) {
                            Text("Select Player 1").tag(nil as Player?)
                            ForEach(allPlayers) { player in
                                Text(player.name).tag(player as Player?)
                            }
                        }
                        TextField("Or enter new name...", text: $newP1Name).textFieldStyle(.roundedBorder).font(.caption)
                    }
                    VStack(alignment: .leading) {
                        Picker("Player 2", selection: $selectedP2) {
                            Text("Select Player 2").tag(nil as Player?)
                            ForEach(allPlayers) { player in
                                Text(player.name).tag(player as Player?)
                            }
                        }
                        TextField("Or enter new name...", text: $newP2Name).textFieldStyle(.roundedBorder).font(.caption)
                    }
                    HStack {
                        Text("Toss for Serve").foregroundStyle(.white).bold()
                        Spacer()
                        if isTossing { ProgressView().padding(.trailing, 10) } else if let result = tossResult {
                            Text(result).bold().foregroundStyle(Color.mintAccent)
                        }
                        Button { flipCoin() } label: { Image(systemName: "coin.fill").foregroundStyle(.yellow) }
                    }
                }
                
                Section(header: Text("Custom Rules").foregroundStyle(.white)) {
                    Stepper("Set Length: \(configuration.setLength)", value: $configuration.setLength, in: 1...20)
                    Stepper("Tie-break Target: \(configuration.tieBreakLength)", value: $configuration.tieBreakLength, in: 1...20)
                    Picker("Best Of", selection: $configuration.bestOf) {
                        Text("Best of 3").tag(3)
                        Text("Best of 5").tag(5)
                    }
                    Toggle("Advantage Scoring", isOn: $configuration.advantageScoring)
                    Toggle("Tie-break at target", isOn: $configuration.setTieBreak)
                    TextField("Location", text: $location)
                }
                
                Section {
                    Button(action: { handleStart() }) {
                        Text("Start Match").frame(maxWidth: .infinity).bold().foregroundStyle(.black)
                    }
                    .buttonStyle(.borderedProminent).tint(Color.mintAccent).disabled(cannotStart)
                }
            }
            .navigationTitle("Match Setup")
        }
    }
    
    private var cannotStart: Bool {
        let p1Missing = (selectedP1 == nil && newP1Name.isEmpty)
        let p2Missing = (selectedP2 == nil && newP2Name.isEmpty)
        return p1Missing || p2Missing
    }
    
    private func flipCoin() {
        isTossing = true; tossResult = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            tossResult = Bool.random() ? "Heads" : "Tails"
            isTossing = false
        }
    }
    
    private func handleStart() {
        let p1: Player
        if let selected = selectedP1 { p1 = selected } else {
            let name = newP1Name.isEmpty ? "Player 1" : newP1Name
            p1 = allPlayers.first(where: { $0.name == name }) ?? Player(name: name)
            if !allPlayers.contains(p1) { modelContext.insert(p1) }
        }
        let p2: Player
        if let selected = selectedP2 { p2 = selected } else {
            let name = newP2Name.isEmpty ? "Player 2" : newP2Name
            p2 = allPlayers.first(where: { $0.name == name }) ?? Player(name: name)
            if !allPlayers.contains(p2) { modelContext.insert(p2) }
        }
        if p1.name == p2.name { return }
        try? modelContext.save()
        onStart(p1, p2)
        dismiss()
    }
}

struct PointEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let player: Player
    let onSave: (PointOutcome, String) -> Void
    @State private var selectedOutcome: PointOutcome = .winner
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Point Details").foregroundStyle(.white)) {
                    VStack(alignment: .center, spacing: 8) {
                        Text("RECORDING POINT FOR").font(.caption2).bold().foregroundStyle(.secondary)
                        Text(player.name).font(.title2).bold().foregroundStyle(Color.mintAccent)
                    }.frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                Section(header: Text("Outcome").foregroundStyle(.white)) {
                    Picker("Type", selection: $selectedOutcome) {
                        ForEach(PointOutcome.allCases) { outcome in
                            Label(outcome.rawValue, systemImage: outcome.icon).tag(outcome)
                        }
                    }.pickerStyle(.navigationLink)
                }
                Section(header: Text("Notes").foregroundStyle(.white)) {
                    TextField("Coaching note...", text: $note, axis: .vertical).lineLimit(3...5)
                }
                Section {
                    Button(action: { onSave(selectedOutcome, note); dismiss() }) {
                        Text("Save Point").bold().frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).tint(Color.mintAccent).foregroundStyle(.black)
                }
            }.navigationTitle("Point Detail").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}
