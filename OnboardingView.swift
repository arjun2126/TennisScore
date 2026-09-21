import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = UserSessionManager.shared
    @State private var currentStep = 0
    
    let steps = [
        OnboardingStep(title: "Professional Scoring", description: "Custom rules, tie-break targets, and the S-G-P layout trusted by serious players.", icon: "tennisball.fill"),
        OnboardingStep(title: "Wrist-Ready", description: "Full control from Apple Watch — start, score, toss, and finish without touching your phone.", icon: "applewatch"),
        OnboardingStep(title: "Live Tracking", description: "Dynamic Island and Lock Screen Live Activities keep every point visible at a glance.", icon: "bell.fill"),
        OnboardingStep(title: "Biometric Tracking", description: "Every match logs heart rate and calories burned, right on your wrist.", icon: "heart.fill"),
        OnboardingStep(title: "Career Analytics", description: "Track your progress, win rates, and head-to-head records against every rival.", icon: "chart.bar.fill"),
        OnboardingStep(title: "Professional Exports", description: "Share high-quality PDF exports of every match with coaches and rivals.", icon: "doc.fill")
    ]
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.courtDark.ignoresSafeArea()
            VStack(spacing: DesignSystem.Spacing.xl) {
                HStack {
                    Spacer()
                    Button {
                        UserSessionManager.shared.completeOnboarding()
                        dismiss()
                    } label: {
                        Text("Skip")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundStyle(DesignSystem.Colors.gray500)
                            .padding(DesignSystem.Spacing.md)
                    }
                    .accessibilityLabel("Skip onboarding")
                }
                
                TabView(selection: $currentStep) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        VStack(spacing: DesignSystem.Spacing.xl) {
                            Image(systemName: steps[index].icon)
                                .font(.system(size: 100))
                                .foregroundStyle(DesignSystem.Colors.mintAccent)
                                .accessibilityHidden(true)
                            
                            Text(steps[index].title)
                                .font(DesignSystem.Typography.displaySmall)
                                .bold()
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            
                            Text(steps[index].description)
                                .font(DesignSystem.Typography.bodyLarge)
                                .foregroundStyle(DesignSystem.Colors.gray700)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DesignSystem.Spacing.xl)
                        }
                        .tag(index)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(steps[index].title). \(steps[index].description)")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .accessibilityLabel("Onboarding steps, swipe to navigate")
                
                Button {
                    if currentStep < steps.count - 1 {
                        withAnimation(DesignSystem.Animation.springMedium) {
                            currentStep += 1
                        }
                    } else {
                        UserSessionManager.shared.completeOnboarding()
                        dismiss()
                    }
                } label: {
                    Text(currentStep == steps.count - 1 ? "Get Started" : "Next")
                        .font(DesignSystem.Typography.labelLarge)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.mintAccent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.xl)
                .accessibilityLabel(currentStep == steps.count - 1 ? "Get started" : "Next step")
            }
        }
    }
}

struct OnboardingStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
}