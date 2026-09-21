import SwiftUI

// MARK: - Colors (self-contained for cross-target compatibility)

extension Color {
    static let courtDark = Color(red: 0.04, green: 0.10, blue: 0.13)
    static let courtMid = Color(red: 0.08, green: 0.16, blue: 0.20)
    static let courtLight = Color(red: 0.12, green: 0.22, blue: 0.28)
    
    static let mintAccent = Color(red: 0.30, green: 1.00, blue: 0.80)
    static let mintAccentDim = Color(red: 0.20, green: 0.80, blue: 0.64)
    static let orangeAccent = Color(red: 1.00, green: 0.58, blue: 0.18)
    static let orangeAccentDim = Color(red: 0.85, green: 0.45, blue: 0.12)
    
    static let success = Color(red: 0.20, green: 0.85, blue: 0.40)
    static let warning = Color(red: 1.00, green: 0.75, blue: 0.10)
    static let error = Color(red: 1.00, green: 0.35, blue: 0.35)
    static let info = Color(red: 0.30, green: 0.70, blue: 1.00)
    
    static let white = Color.white
    static let gray900 = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let gray700 = Color(red: 0.70, green: 0.70, blue: 0.75)
    static let gray500 = Color(red: 0.50, green: 0.50, blue: 0.55)
    static let gray300 = Color(red: 0.35, green: 0.35, blue: 0.40)
    static let gray100 = Color(red: 0.20, green: 0.20, blue: 0.25)
    
    static let glassBackground = Color.white.opacity(0.05)
    static let glassBorder = Color.white.opacity(0.1)
    static let glassHighlight = Color.white.opacity(0.15)
}

// MARK: - Spacing (8pt Grid)

enum Spacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 40
    static let xxxl: CGFloat = 48
}

// MARK: - Corner Radius

enum Radius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
    static let pill: CGFloat = 999
}

// MARK: - Typography (SF Pro Hierarchy)

enum Typography {
    // Display
    static let displayLarge = Font.system(size: 56, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 44, weight: .bold, design: .rounded)
    static let displaySmall = Font.system(size: 36, weight: .bold, design: .rounded)
    
    // Headlines
    static let headlineLarge = Font.system(size: 28, weight: .semibold)
    static let headlineMedium = Font.system(size: 22, weight: .semibold)
    static let headlineSmall = Font.system(size: 18, weight: .semibold)
    
    // Body
    static let bodyLarge = Font.system(size: 17, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .regular)
    static let bodySmall = Font.system(size: 13, weight: .regular)
    
    // Labels
    static let labelLarge = Font.system(size: 14, weight: .medium)
    static let labelMedium = Font.system(size: 12, weight: .medium)
    static let labelSmall = Font.system(size: 11, weight: .medium)
    
    // Caption
    static let captionLarge = Font.system(size: 12, weight: .regular)
    static let captionMedium = Font.system(size: 11, weight: .regular)
    static let captionSmall = Font.system(size: 10, weight: .regular)
    
    // Monospaced (for scores/timers)
    static let monoLarge = Font.system(size: 28, weight: .bold, design: .monospaced)
    static let monoMedium = Font.system(size: 20, weight: .semibold, design: .monospaced)
    static let monoSmall = Font.system(size: 14, weight: .medium, design: .monospaced)
    static let monoXSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
    
    // Score specific
    static let scoreLarge = Font.system(size: 36, weight: .black, design: .rounded)
    static let scoreMedium = Font.system(size: 24, weight: .bold, design: .rounded)
    static let scoreSmall = Font.system(size: 16, weight: .semibold, design: .rounded)
}

// MARK: - Layout

enum Layout {
    static let screenPadding: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let buttonMinHeight: CGFloat = 44
    static let buttonMinWidth: CGFloat = 44
    static let iconSizeSmall: CGFloat = 16
    static let iconSizeMedium: CGFloat = 20
    static let iconSizeLarge: CGFloat = 28
}

// MARK: - Animations

enum Animation {
    static let springFast = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.75, blendDuration: 0)
    static let springMedium = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0)
    static let springSlow = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0)
    static let springBouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)
    
    static let easeOutFast = SwiftUI.Animation.easeOut(duration: 0.15)
    static let easeOutMedium = SwiftUI.Animation.easeOut(duration: 0.25)
    static let easeInOut = SwiftUI.Animation.easeInOut(duration: 0.3)
}

// MARK: - Haptic Manager

#if os(iOS)
struct HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
#elseif os(watchOS)
struct HapticManager {
    static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}
#endif