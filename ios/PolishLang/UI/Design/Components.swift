import SwiftUI

struct LevelBadge: View {
    let level: CEFRLevel

    var body: some View {
        Text(level.rawValue)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("Уровень " + level.rawValue)
    }
}

/// A message block: info, warning or error.
struct Banner: View {
    enum Style {
        case info, warning, error
    }

    let text: String
    var style: Style = .info

    var body: some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
        }
        .font(.callout)
        .foregroundStyle(color)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var icon: String {
        switch style {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        }
    }

    private var color: Color {
        switch style {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
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
                .buttonStyle(.bordered)
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
        HStack(spacing: 4) {
            ForEach(PolishText.diacriticLetters, id: \.self) { letter in
                Button {
                    insert(letter)
                } label: {
                    Text(letter)
                        .font(Theme.polish(.body, weight: .medium))
                        .frame(minWidth: compact ? 32 : nil, maxWidth: compact ? 32 : .infinity, minHeight: 34)
                        .background(Theme.chip, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Вставить " + letter)
            }
        }
    }
}

/// A caption and a text field under it.
struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    var polish = true
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: $text, axis: .vertical)
                .font(polish ? Theme.polish(.body) : .body)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(polish)
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
            HStack(spacing: 10) {
                ForEach(photos.indices, id: \.self) { index in
                    if let image = UIImage(data: photos[index]) {
                        Button {
                            onTap(index)
                        } label: {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 128)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
