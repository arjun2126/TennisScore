import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss // Added to handle closing the screen
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentStep = 0
    
    let steps = [
        OnboardingStep(title: "Welcome to TennisScore", description: "The ultimate tool for tracking your matches with professional precision.", icon: "tennisball.fill"),
        OnboardingStep(title: "Custom Rules", description: "Set your own set lengths, tie-break points, and scoring formats.", icon: "gearshape.2"),
        OnboardingStep(title: "Career Analytics", description: "Track every Ace and Winner to see your growth over time.", icon: "chart.bar.fill")
    ]
    
    var body: some View {
        ZStack {
            Color.courtDark.ignoresSafeArea()
            VStack {
                HStack {
                    Spacer()
                    Button {
                        hasSeenOnboarding = true
                        dismiss() // Explicitly close the screen
                    } label: {
                        Text("Skip").foregroundStyle(.secondary).padding()
                    }
                }
                
                TabView(selection: $currentStep) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        VStack(spacing: 30) {
                            Image(systemName: steps[index].icon)
                                .font(.system(size: 100))
                                .foregroundStyle(Color.mintAccent)
                            
                            Text(steps[index].title)
                                .font(.title).bold().foregroundStyle(.white)
                            
                            Text(steps[index].description)
                                .multilineTextAlignment(.center)
                                .font(.body).foregroundStyle(.secondary)
                                .padding(.horizontal, 40)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                Button {
                    if currentStep < steps.count - 1 {
                        currentStep += 1
                    } else {
                        hasSeenOnboarding = true
                        dismiss() // Explicitly close the screen
                    }
                } label: {
                    Text(currentStep == steps.count - 1 ? "Get Started" : "Next")
                        .bold().frame(maxWidth: .infinity).padding().background(Color.mintAccent).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .padding(30)
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
