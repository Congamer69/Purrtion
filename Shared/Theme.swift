import SwiftUI
import UIKit

enum Theme {
    static let accent = Color(hex: 0xFF8A4A)
    static let accentSoft = Color(light: 0xFFE7D6, dark: 0x302A35)

    static let background = Color(light: 0xFFF8F1, dark: 0x17151B)
    static let card = Color(light: 0xFFFFFF, dark: 0x24212A)
    static let cardAlt = Color(light: 0xF6EEE6, dark: 0x2E2A35)
    static let textPrimary = Color(light: 0x2B2530, dark: 0xF6F0EA)
    static let textSecondary = Color(light: 0x8A8190, dark: 0x9E96A6)
    static let line = Color(light: 0xEFE5DB, dark: 0x38333F)
    /// Pixel-art outline: warm aubergine on light, near-black on dark so sprites keep a crisp edge.
    static let pixelOutline = Color(light: 0x3B2F3F, dark: 0x0C0A10)

    /// Background track for progress bars: tinted in light mode, neutral in dark mode.
    static func track(_ color: Color) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: 0x2E2A35)) : UIColor(color.opacity(0.18))
        })
    }

    static let protein = Color(hex: 0xFF6B8B)
    static let carbs = Color(hex: 0xFFC145)
    static let fat = Color(hex: 0x5BB8F0)
    static let fiber = Color(hex: 0x6BCB77)
    static let water = Color(hex: 0x6EC6FF)
    static let danger = Color(hex: 0xFF5A5F)

    /// Soft shadow tinted like the background (warm in light mode, none needed in dark mode).
    static let cardShadow = Color(light: 0xE9C9AE, dark: 0x000000).opacity(0.35)

    static let radius: CGFloat = 22
    static let radiusSmall: CGFloat = 14

    /// 8-pt spacing scale (use for paddings and gaps).
    enum Space {
        static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 32
    }

    /// Type scale of 2.0: caption 12, body 14, title 17, heading 22, display from 28 up (big numbers).
    /// Call sites keep passing their old sizes; they snap to the nearest step so the whole app stays on four sizes.
    static func snap(_ size: CGFloat) -> CGFloat {
        switch size {
        case ..<13: 12
        case ..<16: 14
        case ..<20: 17
        case ..<26: 22
        default: size
        }
    }

    /// Two weights for text (medium, bold); display numbers (>= 26) may stay heavy.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let w: Font.Weight
        switch weight {
        case .ultraLight, .thin, .light, .regular, .medium: w = .medium
        case .heavy, .black: w = size >= 26 ? .heavy : .bold
        default: w = .bold
        }
        return .system(size: snap(size), weight: w, design: .rounded)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self { case .system: "System"; case .light: "Hell"; case .dark: "Dunkel" }
    }
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .shadow(color: Theme.cardShadow, radius: 14, y: 6)
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardStyle(padding: padding)) }
}

/// Flat button that squishes a bit when pressed.
struct SquishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct PillButtonStyle: ButtonStyle {
    var color: Color = Theme.accent
    var filled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(16, .semibold))
            .foregroundStyle(filled ? Color.white : color)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(filled ? color : color.opacity(0.14), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}


extension Double {
    var clean: String {
        if self == rounded() { return String(Int(self)) }
        return formatted(.number.precision(.fractionLength(0...1)))
    }
    var kcalString: String { Int(rounded()).formatted() }
}
