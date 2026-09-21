import SwiftUI
import SwiftData

/// First-launch profile gate: "Welcome to Vantage. Let's set up your
/// profile." Creates (or adopts) the isCurrentUser player, then releases
/// the user to the Home screen. Self-completes if a profile appears.
struct ProfileSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Player.name) private var players: [Player]
    @State private var name = ""
    @FocusState private var nameFocused: Bool
    
    var onComplete: () -> Void
    
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.courtDark.ignoresSafeArea()
            VStack(spacing: DesignSystem.Spacing.lg) {
                Spacer()
                
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 88))
                    .foregroundStyle(DesignSystem.Colors.mintAccent)
                    .accessibilityHidden(true)
                
                Text("Welcome to Vantage.")
                    .font(DesignSystem.Typography.displaySmall)
                    .bold()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                Text("Let's set up your profile.")
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundStyle(DesignSystem.Colors.gray700)
                    .multilineTextAlignment(.center)
                
                TextField("Your name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(DesignSystem.Typography.bodyMedium)
                    .focused($nameFocused)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.top, DesignSystem.Spacing.md)
                    .accessibilityLabel("Your name")
                    .onSubmit { saveProfile() }
                
                Button(action: saveProfile) {
                    Text("Save Profile")
                        .font(DesignSystem.Typography.labelLarge)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(trimmedName.isEmpty ? DesignSystem.Colors.gray500.opacity(0.3) : DesignSystem.Colors.mintAccent)
                        .foregroundStyle(trimmedName.isEmpty ? .white : .black)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                }
                .disabled(trimmedName.isEmpty)
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .accessibilityLabel("Save profile")
                
                Spacer()
            }
            .padding(.vertical, DesignSystem.Spacing.xl)
        }
        .onAppear { nameFocused = true }
        .onChange(of: players.map(\.isCurrentUser)) { _, flags in
            // Safety: a profile appeared (race) — release to Home.
            if flags.contains(true) {
                onComplete()
            }
        }
    }
    
    private func saveProfile() {
        guard !trimmedName.isEmpty else { return }
        if let existing = players.first(where: { $0.name == trimmedName }) {
            Player.setAsCurrentUser(existing, in: modelContext)
        } else {
            let player = Player(name: trimmedName)
            modelContext.insert(player)
            Player.setAsCurrentUser(player, in: modelContext)
        }
        // First-launch context: explain-then-ask for reminders before Home.
        NotificationManager.shared.requestPermission()
        onComplete()
    }
}
