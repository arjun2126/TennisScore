import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import Combine

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
    @State private var firstServer = 1
    @State private var isTossing = false
    @State private var tossAngle: Double = 0
    @StateObject private var locationManager = LocationManager()
    
    let onStart: (Player, Player, Int) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Player 1")
                            .font(DesignSystem.Typography.captionSmall)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                        Picker("Player 1", selection: $selectedP1) {
                            Text("Select Player 1").tag(nil as Player?)
                            ForEach(allPlayers) { player in
                                Text(player.name).tag(player as Player?)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityLabel("Select player 1")
                        TextField("Or enter new name...", text: $newP1Name)
                            .textFieldStyle(.roundedBorder)
                            .font(DesignSystem.Typography.captionMedium)
                            .accessibilityLabel("Enter player 1 name")
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Player 2")
                            .font(DesignSystem.Typography.captionSmall)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                        Picker("Player 2", selection: $selectedP2) {
                            Text("Select Player 2").tag(nil as Player?)
                            ForEach(allPlayers) { player in
                                Text(player.name).tag(player as Player?)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityLabel("Select player 2")
                        TextField("Or enter new name...", text: $newP2Name)
                            .textFieldStyle(.roundedBorder)
                            .font(DesignSystem.Typography.captionMedium)
                            .accessibilityLabel("Enter player 2 name")
                    }
                } header: {
                    Text("Players")
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .foregroundStyle(DesignSystem.Colors.gray500)
                        .textCase(.uppercase)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Stepper("Set Length: \(configuration.setLength)", value: $configuration.setLength, in: 1...20)
                            .font(DesignSystem.Typography.bodyMedium)
                            .accessibilityLabel("Set length: \(configuration.setLength)")
                        Stepper("Tie-break Target: \(configuration.tieBreakLength)", value: $configuration.tieBreakLength, in: 1...20)
                            .font(DesignSystem.Typography.bodyMedium)
                            .accessibilityLabel("Tie-break target: \(configuration.tieBreakLength)")
                        Picker("Best Of", selection: $configuration.bestOf) {
                            Text("Best of 3").tag(3)
                            Text("Best of 5").tag(5)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Best of \(configuration.bestOf)")
                        Toggle("Advantage Scoring", isOn: $configuration.advantageScoring)
                            .font(DesignSystem.Typography.bodyMedium)
                            .accessibilityLabel("Advantage scoring")
                        Toggle("Tie-break at target", isOn: $configuration.setTieBreak)
                            .font(DesignSystem.Typography.bodyMedium)
                            .accessibilityLabel("Tie-break at set target")
                        TextField("Location", text: $location)
                            .textFieldStyle(.roundedBorder)
                            .font(DesignSystem.Typography.bodyMedium)
                            .accessibilityLabel("Match location")
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "location.fill")
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundStyle(DesignSystem.Colors.mintAccent)
                                .accessibilityHidden(true)
                            Text(locationManager.isLocating ? "Detecting current city…" : "Auto-detected from your location")
                                .font(DesignSystem.Typography.captionMedium)
                                .foregroundStyle(DesignSystem.Colors.gray500)
                            Spacer(minLength: DesignSystem.Spacing.xs)
                            Button(action: { locationManager.requestLocation() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(DesignSystem.Typography.captionMedium)
                                    .foregroundStyle(DesignSystem.Colors.mintAccent)
                            }
                            .accessibilityLabel("Re-detect current location")
                        }
                    }
                    .onAppear {
                        // Smart sensing: pre-fill on open (never overwrites a typed value).
                        if location.isEmpty {
                            locationManager.requestLocation()
                        }
                    }
                    .onReceive(locationManager.$placename) { name in
                        guard let name, !name.isEmpty, location.isEmpty else { return }
                        location = name
                    }
                } header: {
                    Text("Custom Rules")
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .foregroundStyle(DesignSystem.Colors.gray500)
                        .textCase(.uppercase)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Choose who serves first, or let the coin decide.")
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.gray500)

                        Picker("First Server", selection: $firstServer) {
                            Text(firstPlayerLabel).tag(1)
                            Text(secondPlayerLabel).tag(2)
                        }
                        .pickerStyle(.segmented)
                        .disabled(isTossing)
                        .accessibilityLabel("Choose which player serves first")

                        Button(action: tossForServe) {
                            Label(isTossing ? "Tossing..." : "Randomize (Coin Toss)", systemImage: "arrow.triangle.2.circlepath")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundStyle(DesignSystem.Colors.mintAccent)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isTossing)
                        .accessibilityLabel("Toss a coin to decide who serves first")

                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "tennisball.fill")
                                .foregroundStyle(DesignSystem.Colors.mintAccent)
                                .rotationEffect(.degrees(tossAngle))
                            Text("\(firstServer == 1 ? firstPlayerLabel : secondPlayerLabel) serves first")
                                .font(DesignSystem.Typography.bodyMedium)
                                .bold()
                                .foregroundStyle(.white)
                        }
                        .contentTransition(.opacity)
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                } header: {
                    Text("Serve Selection")
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .foregroundStyle(DesignSystem.Colors.gray500)
                        .textCase(.uppercase)
                }
                
                Section {
                    Button(action: { handleStart() }) {
                        Text("Start Match")
                            .font(DesignSystem.Typography.labelLarge)
                            .bold()
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(cannotStart)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Match Setup")
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.courtDark)
            .onAppear {
                // Personal journal: "Me" is always Player 1 when known.
                // Only fills an empty slot — never overwrites a chosen player.
                if selectedP1 == nil && newP1Name.isEmpty,
                   let me = allPlayers.first(where: { $0.isCurrentUser }) {
                    selectedP1 = me
                }
            }
        }
    }
    
    private var cannotStart: Bool {
        let p1Missing = (selectedP1 == nil && newP1Name.isEmpty)
        let p2Missing = (selectedP2 == nil && newP2Name.isEmpty)
        return p1Missing || p2Missing
    }
    
    private var firstPlayerLabel: String {
        selectedP1?.name ?? (newP1Name.isEmpty ? "Player 1" : newP1Name)
    }
    
    private var secondPlayerLabel: String {
        selectedP2?.name ?? (newP2Name.isEmpty ? "Player 2" : newP2Name)
    }
    
    private func tossForServe() {
        guard !isTossing else { return }
        isTossing = true
        tossAngle = 0
        withAnimation(.easeInOut(duration: 1.1)) {
            tossAngle += 360 * Double(Int.random(in: 4...6))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(DesignSystem.Animation.springBouncy) {
                firstServer = Int.random(in: 1...2)
            }
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
        onStart(p1, p2, firstServer)
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
                Section {
                    VStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                        Text("RECORDING POINT FOR")
                            .font(DesignSystem.Typography.captionSmall)
                            .bold()
                            .foregroundStyle(DesignSystem.Colors.gray500)
                        Text(player.name)
                            .font(DesignSystem.Typography.headlineLarge)
                            .bold()
                            .foregroundStyle(DesignSystem.Colors.mintAccent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Recording point for \(player.name)")
                } header: {
                    Text("Point Details")
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .foregroundStyle(DesignSystem.Colors.gray500)
                        .textCase(.uppercase)
                }
                
                Section {
                    Picker("Type", selection: $selectedOutcome) {
                        ForEach(PointOutcome.allCases) { outcome in
                            Label(outcome.rawValue, systemImage: outcome.icon)
                                .font(DesignSystem.Typography.bodyMedium)
                                .tag(outcome)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityLabel("Point outcome type")
                } header: {
                    Text("Outcome")
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .foregroundStyle(DesignSystem.Colors.gray500)
                        .textCase(.uppercase)
                }
                
                Section {
                    TextField("Coaching note...", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                        .font(DesignSystem.Typography.bodyMedium)
                        .accessibilityLabel("Coaching note")
                } header: {
                    Text("Notes")
                        .font(DesignSystem.Typography.captionSmall)
                        .bold()
                        .foregroundStyle(DesignSystem.Colors.gray500)
                        .textCase(.uppercase)
                }
                
                Section {
                    Button(action: { onSave(selectedOutcome, note); dismiss() }) {
                        Text("Save Point")
                            .font(DesignSystem.Typography.labelLarge)
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Point Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(DesignSystem.Typography.labelMedium)
                        .accessibilityLabel("Cancel")
                }
            }
            .presentationDetents([.medium, .large])
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.courtDark)
        }
    }
}

// MARK: - Smart Location Sensing (city-level, one-shot, launch-safe)

/// Fetches the current city once when Match Setup opens and pre-fills the
/// location field. Never runs at app launch, never tracks in the background,
/// and never overwrites a manually typed value.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var placename: String?
    @Published var isLocating = false

    override init() {
        super.init()
        manager.delegate = self
        // City-level accuracy is all we need (and the cheapest).
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func requestLocation() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        guard status == .authorizedWhenInUse || status == .authorizedAlways || status == .notDetermined else { return }
        isLocating = true
        manager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task {
            let name = await Self.reverseGeocode(location)
            await MainActor.run {
                self.isLocating = false
                if !name.isEmpty {
                    self.placename = name
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task {
            await MainActor.run {
                self.isLocating = false
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }

    /// Modern reverse-geocoding (MapKit). Static + Sendable-safe by construction.
    static func reverseGeocode(_ location: CLLocation) async -> String {
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first else { return "" }
        let reps = item.addressRepresentations
        return displayName(
            locality: reps?.cityName,
            subArea: nil,
            adminArea: reps?.regionName,
            country: nil
        )
    }

    /// Pure city formatting — unit-testable without hardware.
    static func displayName(locality: String?, subArea: String?, adminArea: String?, country: String?) -> String {
        if let locality, !locality.isEmpty { return locality }
        if let subArea, !subArea.isEmpty { return subArea }
        if let adminArea, !adminArea.isEmpty { return adminArea }
        if let country, !country.isEmpty { return country }
        return ""
    }
}