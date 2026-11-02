import SwiftUI
import UIKit

/// The answer field of the review: no autocorrection, capitalization or spell checking, and the
/// Polish keyboard opens by itself when it is installed (what lang="pl" does on the web).
struct PolishTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    /// When false the text stays visible but cannot be changed.
    var isEditable = true
    /// Each new value focuses the field again (a new card).
    var focusTrigger = 0
    var onSubmit: () -> Void = {}

    func makeUIView(context: Context) -> PolishUITextField {
        let field = PolishUITextField()
        field.delegate = context.coordinator
        field.placeholder = placeholder
        field.font = UIFont.preferredFont(forTextStyle: .title2).withSerifDesign()
        field.adjustsFontForContentSizeCategory = true
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        field.returnKeyType = .done
        field.clearButtonMode = .whileEditing
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: PolishUITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text {
            field.text = text
        }
        if context.coordinator.focusedTrigger != focusTrigger {
            context.coordinator.focusedTrigger = focusTrigger
            DispatchQueue.main.async {
                field.becomeFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PolishTextField
        var focusedTrigger: Int?

        init(parent: PolishTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            parent.isEditable
        }

        func textFieldShouldClear(_ textField: UITextField) -> Bool {
            parent.isEditable
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }
    }
}

final class PolishUITextField: UITextField {
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage?.hasPrefix("pl") == true } ?? super.textInputMode
    }
}

extension UIFont {
    /// The same font in the serif design ("New York"), which has good Polish diacritics.
    func withSerifDesign() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.serif) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
