import SwiftUI
import SwiftData

struct MatchResultsView: View {
    let match: Match
    var onStartNew: () -> Void
    
    var body: some View {
        NavigationStack { // ADDED: This enables the NavigationLink to work
            ZStack {
                Color.courtDark.ignoresSafeArea()
                VStack(spacing: 30) {
                    VStack(spacing: 15) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.yellow)
                            .shadow(color: .yellow.opacity(0.5), radius: 10)
                        
                        Text("MATCH COMPLETE")
                            .font(.caption)
                            .bold()
                            .tracking(4)
                            .foregroundStyle(.secondary)
                        
                        Text(match.winnerName)
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 50)
                    
                    VStack(spacing: 10) {
                        Text("FINAL SCORE")
                            .font(.caption2)
                            .bold()
                            .foregroundStyle(.secondary)
                        
                        Text(match.setScores)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.mintAccent)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 50)
                    
                    Spacer()
                    
                    VStack(spacing: 15) {
                        NavigationLink(destination: StatsView()) {
                            Label("View Career Stats", systemImage: "chart.bar.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                                .bold()
                        }
                        
                        Button {
                            onStartNew()
                        } label: {
                            Label("Start New Match", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.mintAccent)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                                .bold()
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 50)
                }
            }
        }
    }
}
