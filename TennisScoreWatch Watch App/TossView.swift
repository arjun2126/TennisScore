import SwiftUI

struct TossView: View {
    /// Called when the toss is done (result shown or Done tapped) so the host
    /// can transition straight into the Active Match state.
    var onTossComplete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var rotationAngle: Double = 0
    @State private var result: String?
    @State private var isFlipping = false
    @State private var hasFinished = false

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text("Coin Toss")
                .font(.footnote)
                .bold()
            Text("Who serves first?")
                .font(.caption)
                .foregroundStyle(Color.gray500)

            Button(action: flipCoin) {
                ZStack {
                    Circle().fill(Color.yellow).frame(width: 72, height: 72)
                    Circle().stroke(Color.black.opacity(0.4), lineWidth: 3).frame(width: 72, height: 72)
                    if let result {
                        Text(result == "Heads" ? "H" : "T")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                    } else {
                        Image(systemName: "questionmark")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
                .rotation3DEffect(.degrees(rotationAngle), axis: (x: 0, y: 1, z: 0))
            }
            .buttonStyle(.plain)
            .disabled(isFlipping)

            Text(result ?? (isFlipping ? "Flipping..." : "Tap the coin"))
                .font(.footnote)
                .fontWeight(result == nil ? .regular : .bold)
                .foregroundStyle(result == "Heads" ? Color.mintAccent : (result == "Tails" ? Color.orangeAccent : Color.gray500))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Button("Done") { finishToss() }
                .font(.footnote)
                .fontWeight(.semibold)
        }
        .padding()
    }

    private func flipCoin() {
        guard !isFlipping else { return }
        isFlipping = true
        result = nil
        withAnimation(.easeOut(duration: 1.1)) {
            rotationAngle += 360 * Double(Int.random(in: 4...7))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            result = Bool.random() ? "Heads" : "Tails"
            isFlipping = false
            HapticManager.play(.success)
            // Show the result briefly, then hand off to the Active Match state.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                finishToss()
            }
        }
    }

    private func finishToss() {
        guard !hasFinished else { return }
        hasFinished = true
        if let onTossComplete {
            onTossComplete()
        } else {
            dismiss()
        }
    }
}

#Preview {
    TossView()
}