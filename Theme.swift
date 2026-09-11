import SwiftUI

extension Color {
    static let courtDark = Color(red: 0.04, green: 0.10, blue: 0.13)
    static let mintAccent = Color(red: 0.3, green: 1.0, blue: 0.8)
    static let orangeAccent = Color(red: 1.0, green: 0.6, blue: 0.2)
}

struct HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
