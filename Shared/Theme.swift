import SwiftUI
import UIKit

/// Look & feel choices from Profil → Darstellung. Stored in UserDefaults; the app re-creates its screens when one changes.
enum ThemeAccent: String, CaseIterable, Identifiable {
    case orange, berry, violet, sky, mint, graphite
    var id: String { rawValue }
    var name: String {
        switch self { case .orange: "Orange"; case .berry: "Beere"; case .violet: "Violett"; case .sky: "Himmel"; case .mint: "Minze"; case .graphite: "Graphit" }
    }
    var hex: UInt32 {
        switch self { case .orange: 0xFF8A4A; case .berry: 0xFF5D8F; case .violet: 0x9B7BFF; case .sky: 0x3E9BFF; case .mint: 0x2FBF94; case .graphite: 0x7C7C8A }
    }
}

enum ThemeCorners: String, CaseIterable, Identifiable {
    case compact, normal, round
    var id: String { rawValue }
    var name: String { switch self { case .compact: "Eckig"; case .normal: "Rund"; case .round: "Extra rund" } }
    var radius: CGFloat { switch self { case .compact: 14; case .normal: 22; case .round: 30 } }
    var small: CGFloat { switch self { case .compact: 10; case .normal: 14; case .round: 20 } }
}

enum ThemeCards: String, CaseIterable, Identifiable {
    case shadow, flat, outline
    var id: String { rawValue }
    var name: String { switch self { case .shadow: "Schatten"; case .flat: "Flach"; case .outline: "Rand" } }
}

enum ThemeBackground: String, CaseIterable, Identifiable {
    case warm, neutral, black
    var id: String { rawValue }
    var name: String { switch self { case .warm: "Warm"; case .neutral: "Neutral"; case .black: "Schwarz" } }
}

enum ThemeFont: String, CaseIterable, Identifiable {
    case rounded, standard, serif, mono
    var id: String { rawValue }
    var name: String { switch self { case .rounded: "Rund"; case .standard: "Standard"; case .serif: "Serif"; case .mono: "Mono" } }
    var design: Font.Design { switch self { case .rounded: .rounded; case .standard: .default; case .serif: .serif; case .mono: .monospaced } }
}

enum ThemeSetting {
    static let accentKey = "theme.accent", cornersKey = "theme.corners", cardsKey = "theme.cards", backgroundKey = "theme.bg", fontKey = "theme.font"

    static var accent: ThemeAccent { ThemeAccent(rawValue: UserDefaults.standard.string(forKey: accentKey) ?? "") ?? .orange }
    static var corners: ThemeCorners { ThemeCorners(rawValue: UserDefaults.standard.string(forKey: cornersKey) ?? "") ?? .normal }
    static var cards: ThemeCards { ThemeCards(rawValue: UserDefaults.standard.string(forKey: cardsKey) ?? "") ?? .shadow }
    static var background: ThemeBackground { ThemeBackground(rawValue: UserDefaults.standard.string(forKey: backgroundKey) ?? "") ?? .warm }
    static var font: ThemeFont { ThemeFont(rawValue: UserDefaults.standard.string(forKey: fontKey) ?? "") ?? .rounded }
}

/// One motion vocabulary for the whole app, so everything moves like it belongs together.
enum Motion {
    /// Taps and small state changes: selection, toggles, list edits.
    static let quick = Animation.snappy(duration: 0.32)
    /// Content that changes size or position: expanding rows, cards appearing, theme changes.
    static let smooth = Animation.smooth(duration: 0.4)
    /// Small rewards: water glass, cat reaction, picking a colour.
    static let playful = Animation.spring(duration: 0.45, bounce: 0.3)
    /// Values that fill up: rings and bars. Settles softly, barely overshoots.
    static let fill = Animation.spring(duration: 0.9, bounce: 0.08)
    /// Button press and release.
    static let press = Animation.spring(duration: 0.28, bounce: 0.2)
}

enum Theme {
    static var accent: Color { Color(hex: ThemeSetting.accent.hex) }
    /// Soft tint of the accent for chips and icon backgrounds.
    static var accentSoft: Color {
        let h = ThemeSetting.accent.hex
        return Color(light: mix(h, 0xFFFFFF, 0.84), dark: mix(0x24212A, h, 0.16))
    }

    /// The accent for text and thin icons: darker on light backgrounds, where the vivid fill colour is too pale to read.
    static var accentText: Color {
        let h = ThemeSetting.accent.hex
        return Color(light: mix(h, 0x000000, 0.34), dark: h)
    }

    private static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func ch(_ s: UInt32) -> Double { Double(s) }
        func c(_ shift: UInt32) -> UInt32 {
            UInt32((ch((a >> shift) & 0xFF) * (1 - t) + ch((b >> shift) & 0xFF) * t).rounded())
        }
        return c(16) << 16 | c(8) << 8 | c(0)
    }

    static var background: Color {
        switch ThemeSetting.background {
        case .warm: Color(light: 0xFFF8F1, dark: 0x17151B)
        case .neutral: Color(light: 0xF3F4F6, dark: 0x121214)
        case .black: Color(light: 0xFFFFFF, dark: 0x000000)
        }
    }
    static var card: Color {
        switch ThemeSetting.background {
        case .warm: Color(light: 0xFFFFFF, dark: 0x24212A)
        case .neutral: Color(light: 0xFFFFFF, dark: 0x1D1D20)
        case .black: Color(light: 0xF4F4F6, dark: 0x121214)
        }
    }
    static var cardAlt: Color {
        switch ThemeSetting.background {
        case .warm: Color(light: 0xF6EEE6, dark: 0x2E2A35)
        case .neutral: Color(light: 0xEBECEF, dark: 0x2A2A2E)
        case .black: Color(light: 0xE9E9EC, dark: 0x1D1D20)
        }
    }
    static let textPrimary = Color(light: 0x2B2530, dark: 0xF6F0EA)
    static let textSecondary = Color(light: 0x655D6D, dark: 0x9E96A6)
    static var line: Color {
        switch ThemeSetting.background {
        case .warm: Color(light: 0xEFE5DB, dark: 0x38333F)
        case .neutral: Color(light: 0xE1E2E6, dark: 0x333337)
        case .black: Color(light: 0xE3E3E6, dark: 0x2A2A2E)
        }
    }
    /// Pixel-art outline: warm aubergine on light, near-black on dark so sprites keep a crisp edge.
    static let pixelOutline = Color(light: 0x3B2F3F, dark: 0x0C0A10)

    /// Background track for progress bars: tinted in light mode, neutral in dark mode.
    static func track(_ color: Color) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Theme.cardAlt) : UIColor(color.opacity(0.18))
        })
    }

    static let protein = Color(light: 0xD93A66, dark: 0xFF6B8B)
    static let carbs = Color(light: 0xC98500, dark: 0xFFC145)
    static let fat = Color(light: 0x1F86C8, dark: 0x5BB8F0)
    static let fiber = Color(light: 0x2A9347, dark: 0x6BCB77)
    static let water = Color(light: 0x1C84C4, dark: 0x6EC6FF)
    static let danger = Color(light: 0xD92E34, dark: 0xFF5A5F)

    /// Soft shadow tinted like the background (warm in light mode, none needed in dark mode).
    static var cardShadow: Color {
        guard ThemeSetting.cards == .shadow else { return .clear }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor.black.withAlphaComponent(0.55) : UIColor(red: 0.914, green: 0.788, blue: 0.682, alpha: 0.4) })
    }

    static var radius: CGFloat { ThemeSetting.corners.radius }
    static var radiusSmall: CGFloat { ThemeSetting.corners.small }

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
        return .system(size: snap(size), weight: w, design: ThemeSetting.font.design)
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
            .overlay {
                switch ThemeSetting.cards {
                case .outline:
                    RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.line, lineWidth: 1.5)
                case .shadow:
                    // Faint rim in dark mode, where a shadow alone is hard to see.
                    RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                        .stroke(Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.06) : .clear }), lineWidth: 1)
                case .flat:
                    EmptyView()
                }
            }
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
            .animation(Motion.press, value: configuration.isPressed)
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
            .animation(Motion.press, value: configuration.isPressed)
    }
}


extension Double {
    var clean: String {
        if self == rounded() { return String(Int(self)) }
        return formatted(.number.precision(.fractionLength(0...1)))
    }
    var kcalString: String { Int(rounded()).formatted() }
}
