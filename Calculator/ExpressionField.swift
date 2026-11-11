import SwiftUI
import UIKit

/// Keeps UIKit's native caret, selection handles, hardware keyboard and paste menu,
/// while the calculator keypad remains the on-screen input method.
struct ExpressionField: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    @Binding var editing: Bool
    let fontSize: CGFloat
    var onBeginEditing: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.textAlignment = .right
        field.textColor = .white
        field.tintColor = .systemOrange
        field.borderStyle = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.autocapitalizationType = .none
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.inputView = UIView(frame: .zero)
        field.accessibilityLabel = "Expression. Tap to edit"
        field.accessibilityIdentifier = "expression_editor"
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }
    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        field.font = .systemFont(ofSize: fontSize, weight: .light)
        if field.text != text { field.text = text }
        if editing, field.isFirstResponder,
           let start = field.position(from: field.beginningOfDocument, offset: min(selection.location, (field.text ?? "").utf16.count)),
           let end = field.position(from: start, offset: min(selection.length, max(0, (field.text ?? "").utf16.count - selection.location))) {
            let current = context.coordinator.range(field)
            if current != selection { field.selectedTextRange = field.textRange(from: start, to: end) }
        }
        if editing && !field.isFirstResponder { DispatchQueue.main.async { field.becomeFirstResponder() } }
        if !editing && field.isFirstResponder { field.resignFirstResponder() }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ExpressionField
        init(_ parent: ExpressionField) { self.parent = parent }
        func range(_ field: UITextField) -> NSRange {
            guard let selected = field.selectedTextRange else { return NSRange(location: (field.text ?? "").utf16.count, length: 0) }
            return NSRange(location: field.offset(from: field.beginningOfDocument, to: selected.start), length: field.offset(from: selected.start, to: selected.end))
        }
        func textFieldDidBeginEditing(_ field: UITextField) {
            parent.onBeginEditing()
            parent.selection = range(field)
            parent.editing = true
        }
        func textFieldDidChangeSelection(_ field: UITextField) {
            guard parent.editing else { return }
            let next = range(field)
            if next != parent.selection { parent.selection = next }
        }
        @objc func changed(_ field: UITextField) {
            parent.text = field.text ?? ""
            parent.selection = range(field)
        }
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            (textField.text ?? "").utf16.count - range.length + string.utf16.count <= 2048
        }
    }
}
