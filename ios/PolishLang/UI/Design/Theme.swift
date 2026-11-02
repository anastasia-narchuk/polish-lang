import CoreText
import SwiftUI
import UIKit

/// The design system: palette, type, radii and spacing.
///
/// The shapes, sizes and spacing follow the Wise web design (pill buttons 48/40/32 pt, cards with
/// 24–32 pt corners, 48 pt icon circles, 8 pt progress bars, dark feature cards with pastel
/// headings, Inter with tight headings). The palette is our own: raspberry and wine instead of
/// Wise's lime and forest green.
enum Theme {
    // MARK: Palette

    /// The bright accent: primary buttons, progress, the selected word.
    static let bright = Color(light: 0xFF7E9D, dark: 0xFF7E9D)
    /// Text and icons on `bright`.
    static let onBright = Color(light: 0x3D0A1A, dark: 0x3D0A1A)
    /// Wine: links, icons, selected chips, toggles (the app tint).
    static let ink = Color(light: 0x3D0A1A, dark: 0xFFB3C4)
    /// Text on `ink`.
    static let onInk = Color(light: 0xFFFFFF, dark: 0x2A0611)

    static let text = Color(light: 0x140F11, dark: 0xF5F2F3)
    static let textSecondary = Color(light: 0x4A4446, dark: 0xB9B3B6)
    static let textTertiary = Color(light: 0x6F686A, dark: 0x8E878A)

    /// The screen.
    static let background = Color(light: 0xFFFFFF, dark: 0x121113)
    /// Neutral cards on the screen.
    static let surface = Color(light: 0xF2EEEF, dark: 0x1E1C1E)
    /// Secondary buttons, chips, icon circles, segmented tracks: a wine tint that also works on `surface`.
    static let fill = Color(light: 0x3D0A1A, dark: 0xFFFFFF, lightAlpha: 0.07, darkAlpha: 0.1)
    /// Progress tracks.
    static let track = Color(light: 0x140F11, dark: 0xFFFFFF, lightAlpha: 0.1, darkAlpha: 0.14)
    /// Hairline separators.
    static let line = Color(light: 0x140F11, dark: 0xFFFFFF, lightAlpha: 0.1, darkAlpha: 0.12)
    /// Borders of text fields.
    static let border = Color(light: 0x8C8487, dark: 0x6B6467)

    static let positive = Color(light: 0x1E6B45, dark: 0x7FD4A3)
    static let positiveFill = Color(light: 0xE3F3EA, dark: 0x173326)
    static let warning = Color(light: 0x7A4A00, dark: 0xF3C26B)
    static let warningFill = Color(light: 0xFFF1C7, dark: 0x33280F)
    static let negative = Color(light: 0xB3261E, dark: 0xFF8A80)
    static let negativeFill = Color(light: 0xFDE7E5, dark: 0x3A1A19)

    /// Dark feature cards with a pastel heading, one per section of the app.
    struct Feature {
        let background: Color
        let accent: Color
    }

    static let readingFeature = Feature(background: Color(hex: 0x3D0A1A), accent: Color(hex: 0xFFC2D1))
    static let cardsFeature = Feature(background: Color(hex: 0x0E1B33), accent: Color(hex: 0xA9D7FF))
    static let writingFeature = Feature(background: Color(hex: 0x2B1708), accent: Color(hex: 0xFFE08A))
    static let studyFeature = Feature(background: Color(hex: 0x1E1F22), accent: Color(hex: 0xD5C8FF))

    // MARK: Reader

    /// Long texts stay in a serif ("New York"): about 20 pt, line height about 1.7, about 65 characters.
    static let readerFont = Font.system(.title3, design: .serif)
    static let readerLineSpacing: CGFloat = 10
    static let readerWidth: CGFloat = 640

    /// Words from the learner's cards.
    static let knownWord = Color(light: 0xFFE08A, dark: 0x6B5A1A, lightAlpha: 0.75, darkAlpha: 0.9)
    /// The word or phrase being translated.
    static let selection = Color(light: 0xFF7E9D, dark: 0xFF7E9D, lightAlpha: 0.45, darkAlpha: 0.5)
    /// Dotted underline of key words.
    static let keywordLine = ink

    // MARK: Shapes and spacing

    enum Radius {
        static let hero: CGFloat = 32
        static let card: CGFloat = 24
        static let tile: CGFloat = 16
        static let field: CGFloat = 12
    }

    enum Space {
        /// Side padding of a screen.
        static let screen: CGFloat = 20
        /// Inside a card.
        static let card: CGFloat = 24
        /// Between sections of a screen.
        static let section: CGFloat = 32
    }

    static let maxContentWidth: CGFloat = 640

    // MARK: Type

    /// Polish words and phrases outside the reader: the interface face, so a form reads like a label.
    static func polish(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .ui(style, weight: weight)
    }

    /// Headings are set tight, like on Wise: about −3% at 34 pt, −2% at 28 pt.
    static func tracking(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return -1.0
        case .title: return -0.6
        case .title2: return -0.4
        case .title3: return -0.3
        case .headline: return -0.1
        default: return 0
        }
    }

    // MARK: UIKit parts

    /// Navigation bar titles and tab bar labels in Inter, the tint in wine.
    @MainActor
    static func applyAppearance() {
        let titleColor = UIColor(Theme.text)
        if let large = InterFont.uiFont(.semibold, size: 34, relativeTo: .largeTitle) {
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: large, .foregroundColor: titleColor, .kern: -1.0]
        }
        if let inline = InterFont.uiFont(.semibold, size: 17, relativeTo: .headline) {
            UINavigationBar.appearance().titleTextAttributes = [.font: inline, .foregroundColor: titleColor]
        }
        if let tab = InterFont.uiFont(.medium, size: 10, relativeTo: .caption2) {
            UITabBarItem.appearance().setTitleTextAttributes([.font: tab], for: .normal)
        }
    }
}

// MARK: - Inter

/// Inter (SIL Open Font License, `Fonts/Inter-OFL.txt`) is bundled and registered on first use.
enum InterFont {
    private static let files = ["Inter-Regular", "Inter-Medium", "Inter-SemiBold", "Inter-Bold"]

    /// Registers the bundled files once; false if they are missing, then the system font is used.
    static let isAvailable: Bool = {
        for name in files {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        return UIFont(name: "Inter-Regular", size: 12) != nil
    }()

    static func name(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: return "Inter-Bold"
        case .semibold: return "Inter-SemiBold"
        case .medium: return "Inter-Medium"
        default: return "Inter-Regular"
        }
    }

    static func uiFont(_ weight: Font.Weight, size: CGFloat, relativeTo style: UIFont.TextStyle) -> UIFont? {
        guard isAvailable, let font = UIFont(name: name(for: weight), size: size) else { return nil }
        return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
    }
}

extension Font {
    /// The interface face at a text style's size; it scales with Dynamic Type.
    static func ui(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        let spec = TypeSpec.of(style)
        let resolved = weight ?? spec.weight
        guard InterFont.isAvailable else { return .system(style).weight(resolved) }
        return .custom(InterFont.name(for: resolved), size: spec.size, relativeTo: style)
    }
}

/// Sizes and default weights of the text styles.
private struct TypeSpec {
    let size: CGFloat
    let weight: Font.Weight

    static func of(_ style: Font.TextStyle) -> TypeSpec {
        switch style {
        case .largeTitle: return TypeSpec(size: 34, weight: .semibold)
        case .title: return TypeSpec(size: 28, weight: .semibold)
        case .title2: return TypeSpec(size: 22, weight: .semibold)
        case .title3: return TypeSpec(size: 20, weight: .semibold)
        case .headline: return TypeSpec(size: 17, weight: .semibold)
        case .body: return TypeSpec(size: 17, weight: .regular)
        case .callout: return TypeSpec(size: 16, weight: .regular)
        case .subheadline: return TypeSpec(size: 15, weight: .regular)
        case .footnote: return TypeSpec(size: 14, weight: .regular)
        case .caption: return TypeSpec(size: 12, weight: .medium)
        case .caption2: return TypeSpec(size: 11, weight: .medium)
        default: return TypeSpec(size: 17, weight: .regular)
        }
    }
}

extension View {
    /// A heading: the interface face plus the tight tracking of the style.
    func heading(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> some View {
        font(.ui(style, weight: weight))
            .tracking(Theme.tracking(style))
    }
}

// MARK: - Colors

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: alpha))
    }

    /// A color with light and dark variants.
    init(light: UInt32, dark: UInt32, lightAlpha: Double = 1, darkAlpha: Double = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: CGFloat(alpha)
        )
    }
}
