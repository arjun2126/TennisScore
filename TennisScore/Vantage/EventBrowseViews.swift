import SwiftUI
import SwiftData
import MapKit
import CoreLocation
import Combine

// MARK: - Explore hub (Phase 3: browse public events, filter, map, joins)

struct ExploreFilters {
    var formatRaw: String?
    var maxDistanceKm: Double?
    var freeOnly = false
    var skillBand: ClosedRange<Int>?

    var isDefault: Bool {
        formatRaw == nil && maxDistanceKm == nil && !freeOnly && skillBand == nil
    }
}

struct EventExploreView: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<Event> { $0.visibilityRaw == "publicEvent" && $0.statusRaw == "published" },
        sort: \Event.startDate
    )
    private var events: [Event]

    @StateObject private var location = LocationProvider()
    @State private var filters = ExploreFilters()
    @State private var showMap = false
    @State private var mapSelection: Event?
    @State private var camera: MapCameraPosition = .automatic

    private var filtered: [Event] {
        var result = events
        if let formatRaw = filters.formatRaw {
            result = result.filter { $0.eventTypeRaw == formatRaw }
        }
        if filters.freeOnly {
            result = result.filter { $0.totalCents == 0 }
        }
        if let band = filters.skillBand {
            result = result.filter { $0.skillMin >= band.lowerBound && $0.skillMax <= band.upperBound }
        }
        if let maxKm = filters.maxDistanceKm, let origin = location.coordinate {
            result = result.filter { event in
                guard let km = EventProximity.distanceKm(from: origin.latitude, origin.longitude, to: event) else {
                    return true
                }
                return km <= maxKm
            }
        }
        return result
    }

    private var eventsWithPins: [Event] { filtered.filter { $0.latitude != nil && $0.longitude != nil } }

    var body: some View {
        VStack(spacing: 0) {
            filtersRow
            Picker("Layout", selection: $showMap) {
                Label("List", systemImage: "list.bullet").tag(false)
                Label("Map", systemImage: "map").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.sm)
            if showMap {
                exploreMap
            } else {
                exploreList
            }
        }
        .onAppear(perform: location.requestIfNeeded)
        .sheet(item: $mapSelection) { event in
            NavigationStack {
                EventDetailView(event: event)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { mapSelection = nil }
                        }
                    }
            }
        }
    }

    private var filtersRow: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text("\(filtered.count) open events")
                    .font(DesignSystem.Typography.labelLarge)
                    .foregroundStyle(DesignSystem.Colors.gray900)
                Spacer()
                if !filters.isDefault {
                    Button("Clear") {
                        withAnimation(DesignSystem.Animation.easeOutFast) {
                            filters = ExploreFilters()
                        }
                    }
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundStyle(DesignSystem.Colors.mintAccent)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    formatChip
                    distanceChip
                    feeChip
                    skillChip
                }
            }
            if location.authorizationDenied {
                Text("Location unavailable — distance filters show all events. Enable Location in Settings.")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.gray500)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private func chip(_ title: String, isActive: Bool, options: [ExploreOption]) -> some View {
        Menu {
            ForEach(options) { option in
                Button {
                    option.apply(&filters)
                } label: {
                    if option.isActive(filters) {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                }
            }
        } label: {
            Text(isActive ? "● \(title)" : title)
                .font(DesignSystem.Typography.labelMedium)
                .foregroundStyle(isActive ? DesignSystem.Colors.gray900 : DesignSystem.Colors.gray500)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    Capsule().fill(isActive ? DesignSystem.Colors.mintAccent.opacity(0.22) : Color.white.opacity(0.06))
                )
                .overlay(Capsule().stroke(isActive ? DesignSystem.Colors.mintAccent : DesignSystem.Colors.glassBorder))
        }
    }

    private var formatChip: some View {
        chip(
            filters.formatRaw.map { VantageEventType(rawValue: $0)?.title ?? "Format" } ?? "Format",
            isActive: filters.formatRaw != nil,
            options: [ExploreOption("Any") { $0.formatRaw = nil }]
                + VantageEventType.allCases.map { type in
                    ExploreOption(type.title) { $0.formatRaw = type.rawValue }
                }
        )
    }

    private var distanceChip: some View {
        chip(
            filters.maxDistanceKm.map { "Within \(Int($0))km" } ?? "Distance",
            isActive: filters.maxDistanceKm != nil,
            options: [
                ExploreOption("Anywhere") { $0.maxDistanceKm = nil },
                ExploreOption("Under 10 km") { $0.maxDistanceKm = 10 },
                ExploreOption("Under 25 km") { $0.maxDistanceKm = 25 },
                ExploreOption("Under 50 km") { $0.maxDistanceKm = 50 },
            ]
        )
    }

    private var feeChip: some View {
        chip(
            filters.freeOnly ? "Free" : "Fee",
            isActive: filters.freeOnly,
            options: [
                ExploreOption("Any fee") { $0.freeOnly = false },
                ExploreOption("Free only") { $0.freeOnly = true },
            ]
        )
    }

    private var skillChip: some View {
        chip(
            filters.skillBand.map { "Skill \($0.lowerBound)–\($0.upperBound)" } ?? "Skill",
            isActive: filters.skillBand != nil,
            options: [
                ExploreOption("Any level") { $0.skillBand = nil },
                ExploreOption("Beginner (1–3)") { $0.skillBand = 1...3 },
                ExploreOption("Competitive (4–7)") { $0.skillBand = 4...7 },
                ExploreOption("Advanced (7–10)") { $0.skillBand = 7...10 },
            ]
        )
    }

    private var exploreList: some View {
        Group {
            if filtered.isEmpty {
                ContentUnavailableView(
                    "No Events Found",
                    systemImage: "tray",
                    description: Text("Try widening your filters, or check back later.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(filtered) { event in
                            NavigationLink {
                                EventDetailView(event: event)
                            } label: {
                                EventRow(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var exploreMap: some View {
        Group {
            if eventsWithPins.isEmpty {
                ContentUnavailableView(
                    "No Mapped Events",
                    systemImage: "map",
                    description: Text("Events without a map pin don't appear here.")
                )
            } else {
                Map(position: $camera) {
                    ForEach(eventsWithPins) { event in
                        let coordinate = CLLocationCoordinate2D(latitude: event.latitude!, longitude: event.longitude!)
                        Annotation(event.name, coordinate: coordinate) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(DesignSystem.Colors.mintAccent)
                                .shadow(radius: 2)
                                .onTapGesture { mapSelection = event }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Type-erased filter option used by the explore chips.
struct ExploreOption: Identifiable {
    let id = UUID()
    let title: String
    let apply: (inout ExploreFilters) -> Void
    let isActive: (ExploreFilters) -> Bool

    init(_ title: String, _ apply: @escaping (inout ExploreFilters) -> Void) {
        self.title = title
        self.apply = apply
        self.isActive = { _ in false }
    }
}

// MARK: - Location

@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var authorizationDenied = false

    private let manager = CLLocationManager()
    private var hasRequested = false

    var coordinate: (latitude: Double, longitude: Double)? {
        guard let location else { return nil }
        return (location.coordinate.latitude, location.coordinate.longitude)
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestIfNeeded() {
        if hasRequested { return }
        hasRequested = true
        request()
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            authorizationDenied = true
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.authorizationDenied = false
                self.manager.requestLocation()
            case .denied, .restricted:
                self.authorizationDenied = true
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.location = locations.last
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.authorizationDenied = true
        }
    }
}

/// Tap-to-pin map used by the wizard and any future "near me" flows.
struct LocationPickerMap: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var location = LocationProvider()
    @State private var position: MapCameraPosition
    @State private var marker: CLLocationCoordinate2D?
    @State private var snatchedLocation = false

    let initialLatitude: Double?
    let initialLongitude: Double?
    let onPick: (Double, Double) -> Void

    init(initialLatitude: Double?, initialLongitude: Double?, onPick: @escaping (Double, Double) -> Void) {
        self.initialLatitude = initialLatitude
        self.initialLongitude = initialLongitude
        self.onPick = onPick
        if let initialLatitude, let initialLongitude {
            _position = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: initialLatitude, longitude: initialLongitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))
            _marker = State(initialValue: CLLocationCoordinate2D(latitude: initialLatitude, longitude: initialLongitude))
        } else {
            _position = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 43.879, longitude: -78.657),
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )))
        }
    }

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position) {
                    if let marker {
                        Marker("Event location", coordinate: marker)
                    }
                }
                .onTapGesture { screenPoint in
                    if let coordinate = proxy.convert(screenPoint, from: .local) {
                        marker = coordinate
                    }
                }
            }
            .navigationTitle("Pin the location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Use Pin") {
                        if let marker {
                            onPick(marker.latitude, marker.longitude)
                        }
                        dismiss()
                    }
                    .disabled(marker == nil)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    if let marker {
                        Text("\(marker.latitude.formatted(.number.precision(.fractionLength(4)))), \(marker.longitude.formatted(.number.precision(.fractionLength(4))))")
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                    }
                    Button {
                        if location.coordinate == nil {
                            location.request()
                        }
                        if let coord = location.location?.coordinate {
                            marker = coord
                            withAnimation(DesignSystem.Animation.easeOutFast) {
                                position = .region(MKCoordinateRegion(
                                    center: coord,
                                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                ))
                            }
                        }
                    } label: {
                        Label("Use My Location", systemImage: "location.fill")
                            .font(DesignSystem.Typography.labelMedium)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(DesignSystem.Spacing.md)
                .background(.ultraThinMaterial)
            }
            .onAppear(perform: location.requestIfNeeded)
        }
    }
}

// MARK: - Score entry & disputes (Phase 5)

struct MatchResultSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let match: EventMatch
    let event: Event

    @State private var winner: String
    @State private var scoreLine = ""
    @State private var hasSaved = false

    init(match: EventMatch, event: Event) {
        self.match = match
        self.event = event
        _winner = State(initialValue: match.winnerName ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Match") {
                    Text("\(match.playerAName) vs \(match.playerBName)")
                        .font(DesignSystem.Typography.headlineSmall)
                        .foregroundStyle(DesignSystem.Colors.gray900)
                }
                Section("Winner") {
                    Picker("Winner", selection: $winner) {
                        Text(match.playerAName).tag(match.playerAName)
                        Text(match.playerBName).tag(match.playerBName)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Score (optional)") {
                    TextField("e.g. 6-4 6-3", text: $scoreLine)
                        .keyboardType(.numbersAndPunctuation)
                }
                Section {
                    Button {
                        EventManager.recordResult(
                            match,
                            winner: winner,
                            scoreLine: scoreLine.trimmingCharacters(in: .whitespaces),
                            reporter: EventManager.currentPlayerName(context: context),
                            context: context
                        )
                        hasSaved = true
                        dismiss()
                    } label: {
                        Text(match.isPlayed ? "Update Result" : "Record Result")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(winner.isEmpty)
                }
                Section(footer: Text("Recorded results count toward live standings. Disputed scores are reported to moderation.")) {
                    EmptyView()
                }
            }
            .navigationTitle(match.isPlayed ? "Update Result" : "Record Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct MatchDisputeSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let match: EventMatch
    let event: Event

    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Match") {
                    Text("\(match.playerAName) vs \(match.playerBName)")
                        .font(DesignSystem.Typography.headlineSmall)
                        .foregroundStyle(DesignSystem.Colors.gray900)
                    Text("Flagging a score pauses it until the organiser re-records or resolves it.")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.gray500)
                }
                Section("Why are you disputing this?") {
                    TextField("e.g. I won 6-4 6-3, not the other way", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Button(role: .destructive) {
                        EventManager.flagDispute(
                            match,
                            event: event,
                            note: note.trimmingCharacters(in: .whitespaces).isEmpty ? "Score disagrees" : note.trimmingCharacters(in: .whitespaces),
                            reporter: EventManager.currentPlayerName(context: context),
                            context: context
                        )
                        dismiss()
                    } label: {
                        Text("Flag Dispute")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(note.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Dispute Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Join / report sheets

struct JoinEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let event: Event
    let onConfirm: () -> Void
    let onPaid: (String) -> Void

    @State private var isPurchasing = false

    private var myName: String { EventManager.currentPlayerName(context: context) }
    private var payLabel: String {
        EventFees.currencyString(event.totalCents)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text(event.name)
                            .font(DesignSystem.Typography.headlineMedium)
                            .foregroundStyle(.white)
                        Text("\(event.eventType.title) · \(event.dateLine)")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                    }
                    if event.totalCents > 0 {
                        FeeBreakdownList(event: event)
                        Text("Price shown is exactly what Apple charges you, including the convenience fee.")
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                    } else {
                        Text("Free entry — no charge. We'll confirm your spot below.")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                    }
                    PolicyRow(icon: "scope", text: "Public listing on Explore until the event ends")
                    if event.visibility == .publicEvent {
                        PolicyRow(icon: "checkmark.shield", text: "18+ verified players only, per review")
                    }
                    PolicyRow(icon: "arrow.uturn.backward.circle", text: "Pre-event refunds go through Apple (Report a Problem); your spot is auto-released.")
                }
                .padding(DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Colors.courtDark)
            .navigationTitle("Confirm entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.gray900)
                        .disabled(isPurchasing)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isPurchasing {
                        ProgressView()
                    } else {
                        Button {
                            confirmTapped()
                        } label: {
                            Text(buttonTitle)
                                .font(DesignSystem.Typography.labelLarge)
                        }
                        .foregroundStyle(DesignSystem.Colors.mintAccent)
                    }
                }
            }
            .alert("Purchase", isPresented: purchaseAlertBinding) {
                Button("OK", role: .cancel) { purchaseError = nil }
            } message: {
                Text(purchaseError ?? "")
            }
        }
    }

    private var buttonTitle: String {
        if EventManager.isFull(event) { return "Join Waitlist" }
        if event.totalCents == 0 { return "Confirm Spot" }
        return "Pay \(payLabel)"
    }

    @State private var purchaseError: String?
    private var purchaseAlertBinding: Binding<Bool> {
        Binding(get: { purchaseError != nil }, set: { if !$0 { purchaseError = nil } })
    }

    private func confirmTapped() {
        if EventManager.isFull(event) {
            onConfirm()
            dismiss()
            return
        }
        if event.totalCents == 0 {
            onConfirm()
            dismiss()
            return
        }
        purchaseFlow()
    }

    private func purchaseFlow() {
        isPurchasing = true
        purchaseError = nil
        Task {
            if let pending = EventManager.pendingRegistration(for: event, name: myName, context: context) {
                if let product = await PaymentStore.shared.product(for: event) {
                    switch await PaymentStore.shared.purchase(product, for: event, registration: pending, context: context) {
                    case .success:
                        notifyReminder()
                        isPurchasing = false
                        onPaid("Paid — your spot is confirmed. Apple keeps your receipt; you can refund via Report a Problem.")
                        dismiss()
                    case .pendingReview:
                        isPurchasing = false
                        onPaid("Purchase is under Apple review. Your seat is reserved; you'll be confirmed when it clears.")
                        dismiss()
                    case .userCancelled:
                        isPurchasing = false
                        purchaseError = "Purchase cancelled."
                        EventManager.abandonPending(pending, context: context)
                    case .unavailable(let reason):
                        isPurchasing = false
                        purchaseError = reason
                        EventManager.abandonPending(pending, context: context)
                    }
                } else {
                    isPurchasing = false
                    purchaseError = "This event's fee isn't available as an Apple purchase yet."
                    EventManager.abandonPending(pending, context: context)
                }
            } else {
                isPurchasing = false
                purchaseError = "It looks like you've already joined this event."
            }
        }
    }

    private func notifyReminder() {
        NotificationManager.shared.scheduleEventReminder(
            id: "event-start-\(event.shareToken)",
            date: event.startDate.addingTimeInterval(-3600),
            title: "\(event.name) starts soon 🎾",
            body: "Your spot is confirmed. See you on court!"
        )
    }
}

struct ReportEventSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let event: Event

    @State private var reason = EventModeration.reportReasons[0]
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(event.name)
                        .font(DesignSystem.Typography.headlineSmall)
                        .foregroundStyle(DesignSystem.Colors.gray900)
                    Text(event.locationLabel.isEmpty ? "Unknown location" : event.locationLabel)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundStyle(DesignSystem.Colors.gray500)
                }
                Section("Reason") {
                    Picker("Reason", selection: $reason) {
                        ForEach(EventModeration.reportReasons, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                }
                Section {
                    if submitted {
                        Label("Report submitted — our moderation team reviews it.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.mintAccent)
                    } else {
                        Button("Submit Report") {
                            EventManager.report(
                                event,
                                reason: reason,
                                name: EventManager.currentPlayerName(context: context),
                                context: context
                            )
                            submitted = true
                        }
                        .disabled(submitted)
                    }
                }
            }
            .navigationTitle("Report Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}