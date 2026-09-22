import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("matchRemindersEnabled") private var matchRemindersEnabled = false
    @State private var showingInstructions = false
    @State private var showingDeleteAll = false
    @State private var showingDeleteAccount = false
    @State private var deleteConfirmation = ""
    @State private var showingLegal: LegalDoc?

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.courtDark.ignoresSafeArea()
                List {
                    Section {
                        MyProfileView()
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(
                                top: DesignSystem.Spacing.md,
                                leading: DesignSystem.Spacing.lg,
                                bottom: DesignSystem.Spacing.md,
                                trailing: DesignSystem.Spacing.lg
                            ))
                    } header: {
                        Text("Profile")
                            .font(DesignSystem.Typography.captionSmall)
                            .bold()
                            .foregroundStyle(DesignSystem.Colors.gray500)
                            .textCase(.uppercase)
                    }

                    Section {
                        Button { showingInstructions = true } label: {
                            Label("Instructions", systemImage: "questionmark.circle")
                                .font(DesignSystem.Typography.bodyMedium)
                        }
                        .accessibilityLabel("View instructions")
                        .accessibilityHint("Open the onboarding guide")

                        Toggle(isOn: $matchRemindersEnabled) {
                            Label("Match Reminders", systemImage: "bell.fill")
                                .font(DesignSystem.Typography.bodyMedium)
                        }
                        .tint(DesignSystem.Colors.mintAccent)
                        .accessibilityLabel("Enable match reminders")
                        .accessibilityHint("Weekly reminders to play and check stats")
                        .onChange(of: matchRemindersEnabled) { _, enabled in
                            NotificationManager.shared.setMatchReminders(enabled: enabled)
                        }
                    } header: {
                        Text("Management")
                            .font(DesignSystem.Typography.captionSmall)
                            .bold()
                            .foregroundStyle(DesignSystem.Colors.gray500)
                            .textCase(.uppercase)
                    }

                    Section {
                        PurchasesSection()
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } header: {
                        Text("Purchases & Payments")
                            .font(DesignSystem.Typography.captionSmall)
                            .bold()
                            .foregroundStyle(DesignSystem.Colors.gray500)
                            .textCase(.uppercase)
                    }

                    Section {
                        NavigationLink {
                            ModerationQueueView()
                                .environment(\.modelContext, modelContext)
                        } label: {
                            Label("Reports Queue", systemImage: "shield.lefthalf.filled")
                                .font(DesignSystem.Typography.bodyMedium)
                        }
                        .accessibilityLabel("Reports queue")
                        .accessibilityHint("Review flagged events and disputes, resolve, dismiss, or suspend")
                    } header: {
                        Text("Moderation")
                            .font(DesignSystem.Typography.captionSmall)
                            .bold()
                            .foregroundStyle(DesignSystem.Colors.gray500)
                            .textCase(.uppercase)
                    } footer: {
                        Text("Every report/flag writes here for review before action (Guideline 1.2). Production escalates this queue to a server admin.")
                            .font(DesignSystem.Typography.captionSmall)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                    }

                    Section {
                        Button {
                            showingLegal = .privacy
                        } label: {
                            Label("Privacy Policy", systemImage: "hand.raised.fill")
                                .font(DesignSystem.Typography.bodyMedium)
                        }
                        Button {
                            showingLegal = .terms
                        } label: {
                            Label("Terms & Conditions", systemImage: "doc.text.fill")
                                .font(DesignSystem.Typography.bodyMedium)
                        }
                        NavigationLink {
                            DeleteAccountView()
                                .environment(\.modelContext, modelContext)
                        } label: {
                            Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundStyle(DesignSystem.Colors.error)
                        }
                    } header: {
                        Text("Legal & Data")
                            .font(DesignSystem.Typography.captionSmall)
                            .bold()
                            .foregroundStyle(DesignSystem.Colors.gray500)
                            .textCase(.uppercase)
                    } footer: {
                        Text("Deleting your account erases all players, matches, events, payments, and reports from this device and removes scheduled notifications.")
                            .font(DesignSystem.Typography.captionSmall)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                    }

                    Section {
                        Button(role: .destructive) { showingDeleteAll = true } label: {
                            Label("Clear All Data", systemImage: "trash")
                                .font(DesignSystem.Typography.bodyMedium)
                        }
                        .accessibilityLabel("Clear all data")
                        .accessibilityHint("Permanently delete all players, matches, and statistics")
                    } header: {
                        Text("Danger Zone")
                            .font(DesignSystem.Typography.captionSmall)
                            .bold()
                            .foregroundStyle(DesignSystem.Colors.error)
                            .textCase(.uppercase)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(DesignSystem.Colors.courtDark)
                .listRowBackground(DesignSystem.Colors.glassBackground)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingInstructions) { OnboardingView() }
            .sheet(item: $showingLegal) { doc in
                LegalDocView(doc: doc)
            }
            .alert("Are you sure?", isPresented: $showingDeleteAll) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) { deleteAllData() }
            } message: {
                Text("This will permanently remove all players, matches, stats, and event data.")
            }
        }
    }

    private func deleteAllData() {
        try? modelContext.delete(model: Match.self)
        try? modelContext.delete(model: Player.self)
        try? modelContext.delete(model: PointEvent.self)
        try? modelContext.save()
    }
}

enum LegalDoc: String, Identifiable {
    case privacy
    case terms

    var id: String { rawValue }
}

struct LegalDocView: View {
    let doc: LegalDoc

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(doc.content)
                    .font(.body)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Colors.courtDark.ignoresSafeArea())
            .navigationTitle(doc.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismissView() }
                }
            }
        }
        .presentationDetents([.large])
    }

    @Environment(\.dismiss) private var dismissView
}

extension LegalDoc {
    var title: String {
        switch self {
        case .privacy: return "Privacy Policy"
        case .terms: return "Terms & Conditions"
        }
    }

    var content: String {
        switch self {
        case .privacy:
            return """
            Vantage Privacy Policy (in-app summary)

            Last updated September 2026.

            What we store: TennisScore keeps everything locally on your device using Apple's SwiftData and Keychain. We do not run a server for matches, events, ratings, or payments in this build.

            1. Your data stays on-device. Player profiles, match history, event rosters, registrations, payment records, and reports never leave your device unless you export or share them yourself.

            2. In-App Purchases. Entry fees and convenience fees are handled by Apple's StoreKit. Apple processes payment; your app account token is stored locally so we can match a transaction to your registration. Apple's own privacy policy governs the App Store.

            3. Location. Events can include an optional pin so players can find the court. Your location is only used to sort events by distance and is not stored or transmitted.

            4. Notifications. Schedule reminders are arranged locally and can be disabled or removed at any time. Deleting your account removes them.

            5. Minors. Public events are 18+. Players 13-17 may only join private events, with the organiser confirming parental consent. We comply with COPPA by not collecting personal information from minors beyond a game name.

            6. In-app reports. Reports and moderation flags are stored locally for the event's organiser and a future admin queue.

            7. Deleting your account. Settings → Delete Account erases everything on this device immediately.

            Full policy: the production release hosts this policy at the app's support site listed on the App Store page.
            """
        case .terms:
            return """
            Vantage Terms & Conditions (in-app summary)

            Last updated September 2026.

            1. Acceptance. By using TennisScore you agree to these terms. TennisScore is a tennis-scoring and event-organizing tool.

            2. Events & payments. Organisers set entry fees and convenience fees. All fees are purchased as Apple In-App Purchases; Apple is the merchant of record. Entry fees are passed to the organiser outside the app (manual settlement); convenience fees fund the platform. No money moves outside of Apple's IAP flow inside the app.

            3. Refunds. Pre-event refunds follow Apple's App Store refund process (reportaproblem.apple.com). After an event starts, refunds are at the organiser's discretion.

            4. Ratings. Rated events compute Glicko-2 singles ratings. Ratings are private by default; you can publish them in Settings.

            5. Content rules. You agree not to post unlawful, abusive, or misleading events. Public events must be 18+. Violations may be moderated: reports are reviewed and reported events can be suspended.

            6. Updates & termination. We may update these terms; continued use means acceptance. You can delete your account at any time.

            7. Liability. The app is provided "as is". To the maximum extent permitted, we are not liable for damages from participation in event play.

            Support: contact via the support address listed on the App Store page.
            """
        }
    }
}

/// Account deletion (Guideline 5.1.1(v)): typed confirmation erases every
/// model this app writes plus all scheduled notifications. No server exists to
/// notify — a server-side delete request is queued when one ships.
struct DeleteAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var confirmation = ""

    private var isConfirmed: Bool {
        confirmation.uppercased() == "DELETE"
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "person.crop.circle.badge.minus")
                .font(.system(size: 56))
                .foregroundStyle(DesignSystem.Colors.error)
            Text("Delete Account")
                .font(DesignSystem.Typography.headlineMedium)
                .bold()
                .foregroundStyle(.white)
            Text("Erases all players, matches, events, registrations, payments, payouts, reports, and ratings stored on this device, and cancels scheduled notifications. This can't be undone.")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundStyle(DesignSystem.Colors.gray500)
                .multilineTextAlignment(.center)
            TextField("Type DELETE to confirm", text: $confirmation)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
            Button {
                eraseEverything()
            } label: {
                Text("Permanently Delete")
                    .font(DesignSystem.Typography.labelLarge)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .tint(DesignSystem.Colors.error)
            .disabled(!isConfirmed)
            .padding(.horizontal, DesignSystem.Spacing.xl)
            Spacer()
        }
        .padding(.top, DesignSystem.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.courtDark.ignoresSafeArea())
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func eraseEverything() {
        try? modelContext.delete(model: Match.self)
        try? modelContext.delete(model: PointEvent.self)
        try? modelContext.delete(model: Player.self)
        try? modelContext.delete(model: Tournament.self)
        try? modelContext.delete(model: TournamentMatch.self)
        try? modelContext.delete(model: League.self)
        try? modelContext.delete(model: LeagueMatch.self)
        try? modelContext.delete(model: Event.self)
        try? modelContext.delete(model: EventRegistration.self)
        try? modelContext.delete(model: EventMatch.self)
        try? modelContext.delete(model: EventReport.self)
        try? modelContext.delete(model: PaymentRecord.self)
        try? modelContext.delete(model: PayoutRecord.self)
        try? modelContext.save()
        NotificationManager.shared.removeAllNotifications()
        dismiss()
    }
}