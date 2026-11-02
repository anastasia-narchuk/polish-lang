import SwiftUI

// MARK: - Buttons

/// Pill buttons: 48 pt (large), 40 pt (medium), 32 pt (small).
struct PillButtonStyle: ButtonStyle {
    enum Kind {
        /// Bright fill, wine text: the main action of a screen.
        case primary
        /// Tinted fill, wine text.
        case secondary
        /// No fill: a text action.
        case tertiary
        /// Tinted red fill, red text.
        case destructive
        /// White fill, dark text: the main action on a dark feature card.
        case inverse
    }

    enum Size {
        case large, medium, small
    }

    var kind: Kind = .primary
    var size: Size = .large

    func makeBody(configuration: Configuration) -> some View {
        PillButton(configuration: configuration, kind: kind, size: size)
    }

    private struct PillButton: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind
        let size: Size
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.ui(size == .small ? .subheadline : .headline, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 6)
                .frame(minHeight: height)
                .foregroundStyle(labelColor)
                .background(fillColor, in: Capsule())
                .contentShape(Capsule())
                .opacity(isEnabled ? 1 : 0.45)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }

        private var height: CGFloat {
            switch size {
            case .large: return 48
            case .medium: return 40
            case .small: return 32
            }
        }

        private var horizontalPadding: CGFloat {
            switch size {
            case .large: return 24
            case .medium: return 16
            case .small: return 12
            }
        }

        private var labelColor: Color {
            switch kind {
            case .primary: return Theme.onBright
            case .secondary, .tertiary: return Theme.ink
            case .destructive: return Theme.negative
            case .inverse: return Color(hex: 0x140F11)
            }
        }

        private var fillColor: Color {
            let pressed = configuration.isPressed
            switch kind {
            case .primary: return pressed ? Theme.bright.opacity(0.85) : Theme.bright
            case .secondary: return pressed ? Theme.ink.opacity(0.14) : Theme.fill
            case .tertiary: return pressed ? Theme.fill : Color.clear
            case .destructive: return pressed ? Theme.negative.opacity(0.18) : Theme.negativeFill
            case .inverse: return pressed ? Color.white.opacity(0.85) : Color.white
            }
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static func pill(_ kind: PillButtonStyle.Kind = .primary, size: PillButtonStyle.Size = .large) -> PillButtonStyle {
        PillButtonStyle(kind: kind, size: size)
    }
}

/// A round button with an icon: 48 pt, tinted fill (the "+" of Wise's accordion rows).
struct CircleIconButtonStyle: ButtonStyle {
    var size: CGFloat = 48
    var filled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(filled ? Theme.onBright : Theme.ink)
            .frame(width: size, height: size)
            .background(filled ? Theme.bright : Theme.fill, in: Circle())
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Topic chips and filters: 40 pt pills; the selected one is wine.
struct ChipButtonStyle: ButtonStyle {
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(.subheadline, weight: .medium))
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(isSelected ? Theme.ink : Theme.fill, in: Capsule())
            .foregroundStyle(isSelected ? Theme.onInk : Theme.text)
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Surfaces

/// A neutral rounded block on the screen.
struct CardBackground: ViewModifier {
    var padding: CGFloat = Theme.Space.card
    var radius: CGFloat = Theme.Radius.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func cardBackground(padding: CGFloat = Theme.Space.card, radius: CGFloat = Theme.Radius.card) -> some View {
        modifier(CardBackground(padding: padding, radius: radius))
    }

    /// A screen: white ground, the interface face for text without its own font.
    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}

/// A dark card with a pastel heading. Inside it the dark color variants are used.
struct FeatureCard<Content: View>: View {
    let feature: Theme.Feature
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let title {
                Text(title)
                    .heading(.title)
                    .foregroundStyle(feature.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(Theme.Space.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(feature.background, in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
        .foregroundStyle(Color.white.opacity(0.88))
        .environment(\.colorScheme, .dark)
    }
}

/// An icon in a 48 pt circle.
struct IconCircle: View {
    let systemName: String
    var size: CGFloat = 48
    var tint: Color = Theme.ink
    var fill: Color = Theme.fill

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.4, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(fill, in: Circle())
            .accessibilityHidden(true)
    }
}

/// A section title with an optional text action on the right.
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .heading(.title3)
                .foregroundStyle(Theme.text)
            Spacer(minLength: 8)
            trailing
        }
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.title = title
        self.trailing = EmptyView()
    }
}

/// A list row: icon circle, title, subtitle, something on the right; separated by hairlines.
struct InfoRow<Trailing: View>: View {
    var icon: String?
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 16) {
            if let icon {
                IconCircle(systemName: icon)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.ui(.headline))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.ui(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 14)
        .frame(minHeight: 72)
        .contentShape(Rectangle())
    }
}

extension InfoRow where Trailing == EmptyView {
    init(icon: String? = nil, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailing = EmptyView()
    }
}

/// A hairline between rows.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// "Label — value" on one line.
struct ValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.ui(.body, weight: .semibold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.trailing)
        }
        .font(.ui(.body))
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Controls

/// A pill-shaped segmented control: a tinted track with a white thumb.
struct SegmentedPills<Value: Hashable>: View {
    let items: [Value]
    let title: (Value) -> String
    @Binding var selection: Value
    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                let isSelected = item == selection
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = item }
                } label: {
                    Text(title(item))
                        .font(.ui(.subheadline, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isSelected ? Theme.text : Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Theme.background)
                                    .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1)
                                    .matchedGeometryEffect(id: "thumb", in: thumb)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.fill, in: Capsule())
    }
}

/// An 8 pt progress bar with rounded ends.
struct ProgressBar: View {
    var value: Double
    var tint: Color = Theme.bright
    var track: Color = Theme.track
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let fraction = min(1, max(0, value))
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                if fraction > 0 {
                    Capsule()
                        .fill(tint)
                        .frame(width: max(height, geometry.size.width * fraction))
                }
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue("\(Int((min(1, max(0, value)) * 100).rounded())) %")
    }
}

/// A bordered text field box; the border turns wine and thicker while editing.
struct FieldBackground: ViewModifier {
    var isFocused = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 52)
            .background(Theme.background, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                    .strokeBorder(isFocused ? Theme.ink : Theme.border, lineWidth: isFocused ? 2 : 1)
            }
    }
}

extension View {
    func fieldBackground(isFocused: Bool = false) -> some View {
        modifier(FieldBackground(isFocused: isFocused))
    }
}

/// A small rounded tag: level, source, status.
struct Tag: View {
    enum Style {
        case neutral, accent, warning, positive, negative
    }

    let text: String
    var style: Style = .neutral

    var body: some View {
        Text(text)
            .font(.ui(.caption, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(fillColor, in: Capsule())
            .foregroundStyle(labelColor)
    }

    private var fillColor: Color {
        switch style {
        case .neutral: return Theme.fill
        case .accent: return Theme.bright
        case .warning: return Theme.warningFill
        case .positive: return Theme.positiveFill
        case .negative: return Theme.negativeFill
        }
    }

    private var labelColor: Color {
        switch style {
        case .neutral: return Theme.textSecondary
        case .accent: return Theme.onBright
        case .warning: return Theme.warning
        case .positive: return Theme.positive
        case .negative: return Theme.negative
        }
    }
}

struct LevelBadge: View {
    let level: CEFRLevel

    var body: some View {
        Tag(text: level.rawValue, style: .accent)
            .accessibilityLabel("Уровень " + level.rawValue)
    }
}

/// A message block: info, warning, error or success.
struct Banner: View {
    enum Style {
        case info, warning, error, success
    }

    let text: String
    var style: Style = .info

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 22)
                .accessibilityHidden(true)
            Text(text)
                .font(.ui(.callout))
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(fillColor, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
    }

    private var icon: String {
        switch style {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        case .success: return "checkmark.circle"
        }
    }

    private var iconColor: Color {
        switch style {
        case .info: return Theme.ink
        case .warning: return Theme.warning
        case .error: return Theme.negative
        case .success: return Theme.positive
        }
    }

    private var textColor: Color {
        style == .info ? Theme.text : iconColor
    }

    private var fillColor: Color {
        switch style {
        case .info: return Theme.fill
        case .warning: return Theme.warningFill
        case .error: return Theme.negativeFill
        case .success: return Theme.positiveFill
        }
    }
}

/// A spinner with a line of text and an optional "Стоп".
struct WorkingRow: View {
    let text: String
    var stop: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Theme.ink)
            Text(text)
                .font(.ui(.callout))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            if let stop {
                Button("Стоп", action: stop)
                    .buttonStyle(.pill(.secondary, size: .small))
            }
        }
    }
}

/// An empty screen: a big icon circle, a title, a line of text and actions.
struct EmptyState<Actions: View>: View {
    let icon: String
    let title: String
    let text: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 16) {
            IconCircle(systemName: icon, size: 72)
            Text(title)
                .heading(.title2)
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            Text(text)
                .font(.ui(.body))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            actions
                .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension EmptyState where Actions == EmptyView {
    init(icon: String, title: String, text: String) {
        self.icon = icon
        self.title = title
        self.text = text
        self.actions = EmptyView()
    }
}

/// "Ещё раз" that stays disabled until `retryAfter` (TZ 2, section 7: "Подожди минуту").
struct RetryButton: View {
    var retryAfter: Date?
    var action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let wait = retryAfter.map { max(0, Int($0.timeIntervalSince(context.date).rounded(.up))) } ?? 0
            let title = wait > 0 ? "Ещё раз — через \(wait) с" : "Ещё раз"
            Button(title, action: action)
                .buttonStyle(.pill(.secondary, size: .medium))
                .disabled(wait > 0)
        }
    }
}

/// Letters a Russian keyboard does not have.
struct PolishLettersBar: View {
    /// Fixed-width keys, for the toolbar above the keyboard.
    var compact = false
    var insert: (String) -> Void

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            ForEach(PolishText.diacriticLetters, id: \.self) { letter in
                Button {
                    insert(letter)
                } label: {
                    Text(letter)
                        .font(.ui(.title3, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .frame(minWidth: compact ? 32 : nil, maxWidth: compact ? 32 : .infinity, minHeight: compact ? 34 : 44)
                        .background(Theme.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Вставить " + letter)
            }
        }
    }
}

/// A caption and a bordered text field under it.
struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    var polish = true
    var keyboard: UIKeyboardType = .default
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.ui(.footnote, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            TextField(title, text: $text, axis: .vertical)
                .font(.ui(.body))
                .foregroundStyle(Theme.text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(polish)
                .focused($focused)
                .fieldBackground(isFocused: focused)
        }
    }
}

/// Lays children out in rows, wrapping like words (topic chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            widest = max(widest, x + size.width)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// Photos the words were recognized from, as a row of thumbnails.
struct PhotoStrip: View {
    let photos: [Data]
    var onTap: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(photos.indices, id: \.self) { index in
                    if let image = UIImage(data: photos[index]) {
                        Button {
                            onTap(index)
                        } label: {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 128)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Фото \(index + 1), открыть")
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct PhotoPage: Identifiable {
    let index: Int
    var id: Int { index }
}

/// Full-screen photos with pinch to zoom, for checking words against the original.
struct PhotoViewer: View {
    let photos: [Data]
    @State var index: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $index) {
                ForEach(photos.indices, id: \.self) { page in
                    ZoomableImage(data: photos[page])
                        .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

private struct ZoomableImage: View {
    let data: Data
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            if let image = UIImage(data: data) {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width * scale, height: geometry.size.height * scale)
                }
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { value in scale = min(5, max(1, baseScale * value.magnification)) }
                        .onEnded { _ in baseScale = scale }
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        scale = scale > 1 ? 1 : 2.5
                        baseScale = scale
                    }
                }
            }
        }
    }
}
