import CoreText
import SwiftUI
import UIKit

/// Line metrics shared by the text view and the squared paper behind it, so the text sits on the grid.
struct NotebookMetrics {
    /// Side of a square of the grid.
    static let cell: CGFloat = 15
    /// The red margin line, from the left edge.
    static let margin: CGFloat = 30

    let font: UIFont
    let lineHeight: CGFloat

    /// A serif with full Polish diacritics, at least 19 pt (TZ 3: "минимум 18px"), scaled with Dynamic Type.
    static var current: NotebookMetrics {
        let base = UIFont.systemFont(ofSize: 19).withSerifDesign()
        let font = UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
        let lines = max(2, (font.lineHeight * 1.25 / cell).rounded(.up))
        return NotebookMetrics(font: font, lineHeight: lines * cell)
    }

    var insets: UIEdgeInsets {
        UIEdgeInsets(top: Self.cell, left: Self.margin + 10, bottom: Self.cell, right: 14)
    }

    /// Where the glyphs of the first line start: line boxes keep their extra height above the text.
    var firstLineTop: CGFloat {
        insets.top + max(0, lineHeight - font.lineHeight)
    }

    var attributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        return [.font: font, .paragraphStyle: paragraph, .foregroundColor: UIColor(Theme.text)]
    }
}

/// The writing field: a squared notebook sheet with a red margin (TZ 3, 4.2 and 11).
/// No autocorrection, capitalization or spell checking; the Polish keyboard opens by itself when
/// it is installed; the ą ć ę ł ń ó ś ź ż bar over the keyboard types at the cursor.
struct NotebookField: View {
    @Binding var text: String
    var placeholder = "Pisz tutaj…"
    var lettersBar = true
    var isEditable = true
    var minLines = 10
    /// Demo screenshots: type a letter through the bar at this offset after launch.
    var demoInsertion: (letter: String, offset: Int)?

    var body: some View {
        let metrics = NotebookMetrics.current
        NotebookEditor(text: $text, lettersBar: lettersBar, isEditable: isEditable, minLines: minLines, demoInsertion: demoInsertion)
            .background(NotebookPaper())
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Font(metrics.font as CTFont))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.leading, metrics.insets.left)
                        .padding(.top, metrics.firstLineTop)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            }
    }
}

/// Squares and the red margin line, drawn behind the transparent text view.
struct NotebookPaper: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.notebookPaper))
            var grid = Path()
            var y = NotebookMetrics.cell
            while y < size.height {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
                y += NotebookMetrics.cell
            }
            var x = NotebookMetrics.cell
            while x < size.width {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
                x += NotebookMetrics.cell
            }
            context.stroke(grid, with: .color(Theme.notebookGrid), lineWidth: 0.6)
            var margin = Path()
            margin.move(to: CGPoint(x: NotebookMetrics.margin, y: 0))
            margin.addLine(to: CGPoint(x: NotebookMetrics.margin, y: size.height))
            context.stroke(margin, with: .color(Theme.notebookMargin), lineWidth: 1.2)
        }
        .accessibilityHidden(true)
    }
}

struct NotebookEditor: UIViewRepresentable {
    @Binding var text: String
    var lettersBar: Bool
    var isEditable: Bool
    var minLines: Int
    var demoInsertion: (letter: String, offset: Int)?

    func makeUIView(context: Context) -> NotebookTextView {
        let metrics = NotebookMetrics.current
        let view = NotebookTextView()
        view.delegate = context.coordinator
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textColor = UIColor(Theme.text)
        view.tintColor = UIColor(Theme.ink)
        view.font = metrics.font
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
        view.spellCheckingType = .no
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.textContainerInset = metrics.insets
        view.textContainer.lineFragmentPadding = 0
        view.typingAttributes = metrics.attributes
        view.attributedText = NSAttributedString(string: text, attributes: metrics.attributes)
        view.adjustsFontForContentSizeCategory = false
        view.accessibilityLabel = "Текст по-польски"
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setLettersBar(lettersBar && isEditable)
        view.isEditable = isEditable
        if let demoInsertion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                view.becomeFirstResponder()
                let length = (view.text as NSString).length
                view.selectedRange = NSRange(location: min(demoInsertion.offset, length), length: 0)
                view.insertPolishLetter(demoInsertion.letter)
            }
        }
        return view
    }

    func updateUIView(_ view: NotebookTextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text {
            let metrics = NotebookMetrics.current
            let selection = view.selectedRange
            view.attributedText = NSAttributedString(string: text, attributes: metrics.attributes)
            let length = (text as NSString).length
            view.selectedRange = NSRange(location: min(selection.location, length), length: 0)
            view.invalidateIntrinsicContentSize()
        }
        if view.isEditable != isEditable {
            view.isEditable = isEditable
        }
        view.setLettersBar(lettersBar && isEditable)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NotebookTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0, width.isFinite else { return nil }
        let metrics = NotebookMetrics.current
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let minimum = CGFloat(minLines) * metrics.lineHeight + metrics.insets.top + metrics.insets.bottom
        return CGSize(width: width, height: max(fitting.height, minimum))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NotebookEditor

        init(parent: NotebookEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            if parent.text != textView.text {
                parent.text = textView.text
            }
            textView.invalidateIntrinsicContentSize()
        }
    }
}

final class NotebookTextView: UITextView {
    private var lettersView: PolishLettersInputView?

    /// The Polish keyboard, if installed (what lang="pl" does on the web).
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage?.hasPrefix("pl") == true } ?? super.textInputMode
    }

    func setLettersBar(_ shown: Bool) {
        guard shown != (lettersView != nil) else { return }
        lettersView = shown ? PolishLettersInputView(target: self) : nil
        inputAccessoryView = lettersView
        if isFirstResponder { reloadInputViews() }
    }

    /// Types the letter at the cursor (replacing a selection); the field keeps the focus (TZ 3, criterion 8).
    func insertPolishLetter(_ letter: String) {
        let before = text
        insertText(letter)
        if text != before {
            delegate?.textViewDidChange?(self)
        }
    }
}

/// ą ć ę ł ń ó ś ź ż and Shift over the keyboard. Its buttons never take the focus from the text.
final class PolishLettersInputView: UIInputView {
    private weak var target: NotebookTextView?
    private var uppercase = false
    private var letterButtons: [UIButton] = []
    private let shiftButton = UIButton(type: .system)

    init(target: NotebookTextView) {
        self.target = target
        super.init(frame: CGRect(x: 0, y: 0, width: 320, height: 50), inputViewStyle: .default)
        allowsSelfSizing = true
        // Opaque: the iOS 26 keyboard is glass, and the text must not show through the bar.
        backgroundColor = UIColor(Theme.surface)
        let hairline = UIView()
        hairline.backgroundColor = UIColor(Theme.line)
        hairline.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hairline)
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        shiftButton.setImage(UIImage(systemName: "shift"), for: .normal)
        shiftButton.accessibilityLabel = "Заглавная буква"
        shiftButton.addTarget(self, action: #selector(toggleShift), for: .touchUpInside)
        style(shiftButton)
        stack.addArrangedSubview(shiftButton)
        for (index, letter) in PolishText.diacriticLetters.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.setTitle(letter, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 21, weight: .medium)
            button.accessibilityLabel = "Вставить " + letter
            button.addTarget(self, action: #selector(typeLetter(_:)), for: .touchUpInside)
            style(button)
            letterButtons.append(button)
            stack.addArrangedSubview(button)
        }
        addSubview(stack)
        NSLayoutConstraint.activate([
            hairline.topAnchor.constraint(equalTo: topAnchor),
            hairline.leadingAnchor.constraint(equalTo: leadingAnchor),
            hairline.trailingAnchor.constraint(equalTo: trailingAnchor),
            hairline.heightAnchor.constraint(equalToConstant: 1),
            stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            stack.heightAnchor.constraint(equalToConstant: 38),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// Like keyboard keys: opaque, with a thin shadow under them.
    private func style(_ button: UIButton) {
        button.backgroundColor = UIColor(Theme.background)
        button.tintColor = UIColor(Theme.text)
        button.setTitleColor(UIColor(Theme.text), for: .normal)
        button.layer.cornerRadius = 8
        button.layer.cornerCurve = .continuous
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.18
        button.layer.shadowRadius = 0
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
    }

    @objc private func typeLetter(_ sender: UIButton) {
        let letter = PolishText.diacriticLetters[sender.tag]
        target?.insertPolishLetter(uppercase ? letter.uppercased() : letter)
        // Like the keyboard: Shift is for one letter.
        if uppercase { setUppercase(false) }
    }

    @objc private func toggleShift() {
        setUppercase(!uppercase)
    }

    private func setUppercase(_ value: Bool) {
        uppercase = value
        shiftButton.setImage(UIImage(systemName: value ? "shift.fill" : "shift"), for: .normal)
        shiftButton.accessibilityValue = value ? "включена" : "выключена"
        for button in letterButtons {
            let letter = PolishText.diacriticLetters[button.tag]
            button.setTitle(value ? letter.uppercased() : letter, for: .normal)
        }
    }
}
