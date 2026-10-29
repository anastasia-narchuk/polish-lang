import SwiftUI

enum Theme {
    /// Polish text is set in the serif system font ("New York"): it has good diacritics.
    static func polish(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        Font.system(style, design: .serif).weight(weight)
    }

    /// Reader: a serif face around 20 pt, line height about 1.7, a column of about 65 characters.
    static let readerFont = Font.system(.title3, design: .serif)
    static let readerLineSpacing: CGFloat = 10
    static let readerWidth: CGFloat = 640

    /// Words from the learner's cards.
    static let knownWord = Color.yellow.opacity(0.32)
    /// The word or phrase being translated.
    static let selection = Color.accentColor.opacity(0.25)
    /// Dotted underline of key words.
    static let keywordLine = Color.accentColor

    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let chip = Color(uiColor: .tertiarySystemFill)
}

struct ChipButtonStyle: ButtonStyle {
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Theme.chip, in: Capsule())
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// A rounded block on the grouped background.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func cardBackground() -> some View {
        modifier(CardBackground())
    }
}
