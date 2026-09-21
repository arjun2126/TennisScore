import SwiftUI

// MARK: - Design System

/// Centralized design tokens for consistent spacing, typography, colors, and animations
enum DesignSystem {
    
    // MARK: - Spacing (8pt Grid)
    
    enum Spacing {
        static let xxxs: CGFloat = 2   // 0.25 * 8
        static let xxs: CGFloat = 4    // 0.5 * 8
        static let xs: CGFloat = 8     // 1 * 8
        static let sm: CGFloat = 12    // 1.5 * 8
        static let md: CGFloat = 16    // 2 * 8
        static let lg: CGFloat = 24    // 3 * 8
        static let xl: CGFloat = 32    // 4 * 8
        static let xxl: CGFloat = 40   // 5 * 8
        static let xxxl: CGFloat = 48  // 6 * 8
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
    
    // MARK: - Colors (High Contrast for Outdoor)
    
    enum Colors {
        // Court theme
        static let courtDark = Color(red: 0.04, green: 0.10, blue: 0.13)
        static let courtMid = Color(red: 0.08, green: 0.16, blue: 0.20)
        static let courtLight = Color(red: 0.12, green: 0.22, blue: 0.28)
        
        // Accents (WCAG AA compliant on dark)
        static let mintAccent = Color(red: 0.30, green: 1.00, blue: 0.80)
        static let mintAccentDim = Color(red: 0.20, green: 0.80, blue: 0.64)
        static let orangeAccent = Color(red: 1.00, green: 0.58, blue: 0.18)
        static let orangeAccentDim = Color(red: 0.85, green: 0.45, blue: 0.12)
        
        // Semantic
        static let success = Color(red: 0.20, green: 0.85, blue: 0.40)
        static let warning = Color(red: 1.00, green: 0.75, blue: 0.10)
        static let error = Color(red: 1.00, green: 0.35, blue: 0.35)
        static let info = Color(red: 0.30, green: 0.70, blue: 1.00)
        
        // Neutral (high contrast)
        static let white = Color.white
        static let gray900 = Color(red: 0.95, green: 0.95, blue: 0.97)
        static let gray700 = Color(red: 0.70, green: 0.70, blue: 0.75)
        static let gray500 = Color(red: 0.50, green: 0.50, blue: 0.55)
        static let gray300 = Color(red: 0.35, green: 0.35, blue: 0.40)
        static let gray100 = Color(red: 0.20, green: 0.20, blue: 0.25)
        
        // Glassmorphism
        static let glassBackground = Color.white.opacity(0.05)
        static let glassBorder = Color.white.opacity(0.1)
        static let glassHighlight = Color.white.opacity(0.15)
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
    
    // MARK: - Shadows
    
    enum Shadow {
        static let subtle = (color: Color.black.opacity(0.1), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let medium = (color: Color.black.opacity(0.2), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        static let elevated = (color: Color.black.opacity(0.3), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
        static let glowMint = (color: Color.mintAccent.opacity(0.4), radius: CGFloat(20), x: CGFloat(0), y: CGFloat(0))
        static let glowOrange = (color: Color.orangeAccent.opacity(0.4), radius: CGFloat(20), x: CGFloat(0), y: CGFloat(0))
    }
    
    // MARK: - Layout
    
    enum Layout {
        static let screenPadding: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let buttonMinHeight: CGFloat = 44  // HIG minimum
        static let buttonMinWidth: CGFloat = 44
        static let iconSizeSmall: CGFloat = 16
        static let iconSizeMedium: CGFloat = 20
        static let iconSizeLarge: CGFloat = 28
    }
}

// MARK: - View Extensions for Design System

extension View {
    /// Applies glassmorphism card style
    func glassCard(cornerRadius: CGFloat = DesignSystem.Radius.lg, padding: CGFloat = DesignSystem.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignSystem.Colors.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(DesignSystem.Colors.glassBorder, lineWidth: 0.5)
                    )
            )
    }
    
    /// Applies elevated glass card with shadow
    func elevatedGlassCard(cornerRadius: CGFloat = DesignSystem.Radius.lg, padding: CGFloat = DesignSystem.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignSystem.Colors.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(DesignSystem.Colors.glassBorder, lineWidth: 0.5)
                    )
                    .shadow(
                        color: DesignSystem.Shadow.medium.color,
                        radius: DesignSystem.Shadow.medium.radius,
                        x: DesignSystem.Shadow.medium.x,
                        y: DesignSystem.Shadow.medium.y
                    )
            )
    }
    
    /// Standard screen container
    func screenContainer() -> some View {
        self
            .padding(.horizontal, DesignSystem.Layout.screenPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.Colors.courtDark)
    }
    
    /// Score transition animation
    func scoreTransition() -> some View {
        self
            .animation(DesignSystem.Animation.springBouncy, value: UUID())
    }
    
    /// HIG-compliant touch target
    func touchTarget(minSize: CGFloat = DesignSystem.Layout.buttonMinHeight) -> some View {
        self
            .frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = DesignSystem.Colors.mintAccent
    var foreground: Color = .black
    var cornerRadius: CGFloat = DesignSystem.Radius.md
    var minHeight: CGFloat = DesignSystem.Layout.buttonMinHeight
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.labelLarge)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1.0))
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animation.springFast, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var color: Color = DesignSystem.Colors.mintAccent
    var cornerRadius: CGFloat = DesignSystem.Radius.md
    var minHeight: CGFloat = DesignSystem.Layout.buttonMinHeight
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.labelLarge)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(color.opacity(configuration.isPressed ? 0.3 : 0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color.opacity(configuration.isPressed ? 0.5 : 0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animation.springFast, value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = DesignSystem.Radius.md
    var minHeight: CGFloat = DesignSystem.Layout.buttonMinHeight
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.labelLarge)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(DesignSystem.Colors.error.opacity(configuration.isPressed ? 0.7 : 0.2))
            .foregroundStyle(DesignSystem.Colors.error)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animation.springFast, value: configuration.isPressed)
    }
}

struct PlainIconButtonStyle: ButtonStyle {
    var size: CGFloat = DesignSystem.Layout.buttonMinHeight
    var background: Color = Color.white.opacity(0.1)
    var foreground: Color = .white
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(background.opacity(configuration.isPressed ? 0.5 : 1.0))
            .foregroundStyle(foreground)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(DesignSystem.Animation.springFast, value: configuration.isPressed)
    }
}

// MARK: - Score Box Component

struct ScoreBox: View {
    let value: String
    let label: String
    let color: Color
    var isServing: Bool = false
    var animate: Bool = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Text(value)
                .font(DesignSystem.Typography.scoreSmall)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(DesignSystem.Animation.springBouncy, value: value)
            
            HStack(spacing: DesignSystem.Spacing.xxxs) {
                Text(label)
                    .font(DesignSystem.Typography.captionSmall)
                    .fontWeight(.black)
                    .foregroundStyle(color)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, DesignSystem.Spacing.xxxs)
                    .background(color.opacity(0.2))
                    .clipShape(Capsule())
                
                if isServing {
                    Image(systemName: "tennisball.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(color)
                        .symbolEffect(.bounce, options: .repeating)
                }
            }
        }
        .frame(width: 48, height: 48)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
    }
}

// MARK: - Player Name Banner

struct PlayerNameBanner: View {
    let name: String
    let color: Color
    var isServing: Bool = false
    var isEditing: Bool = false
    let onLongPress: () -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(name)
                .font(DesignSystem.Typography.headlineMedium)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            if isServing {
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)
                    .symbolEffect(.bounce, options: .repeating)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onLongPressGesture { onLongPress() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name)\(isServing ? ", serving" : "")")
        .accessibilityHint("Double tap to edit name")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let text: String
    let color: Color
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xxxs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(DesignSystem.Typography.captionSmall)
                .fontWeight(.bold)
                .tracking(1)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xxxs)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// MARK: - Animated Counter (for smooth score transitions)

struct AnimatedCounter: View {
    let value: Int
    let font: Font
    let color: Color
    
    @State private var displayedValue: Int = 0
    
    var body: some View {
        Text("\(displayedValue)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .onAppear { displayedValue = value }
            .onChange(of: value) { _, newValue in
                withAnimation(DesignSystem.Animation.springBouncy) {
                    displayedValue = newValue
                }
            }
    }
}

// MARK: - Haptic Manager (Cross-platform, defined in Theme.swift)