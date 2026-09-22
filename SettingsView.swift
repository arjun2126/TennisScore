import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("matchRemindersEnabled") private var matchRemindersEnabled = false
    @State private var showingInstructions = false
    @State private var showingDeleteAll = false
    
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
            .alert("Are you sure?", isPresented: $showingDeleteAll) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) { deleteAllData() }
            } message: {
                Text("This will permanently remove all players, matches, and stats.")
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