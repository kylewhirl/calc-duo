// Adapted from bofeiw/ios-calculator-clone-for-ipados (CC0-1.0).
import SwiftUI

enum DisplayAreaEvent { case Delete, CopyToClipBoard, Paste }

struct DisplayArea: View {
    var eventCallback: (DisplayAreaEvent) -> Void
    let currentDisplay: String
    let buttonSize: CGFloat
    var previewValue: String? = nil
    var expression: String? = nil
    var editingAction: (() -> Void)? = nil
    var scientificAction: (() -> Void)? = nil
    var historyAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if let expression {
                Text(expression).font(.system(size: buttonSize * 0.30, weight: .regular))
                    .foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.18)
                    .accessibilityIdentifier("calculator_expression")
            }
            Text(previewValue ?? currentDisplay)
                .font(.system(size: buttonSize * (expression == nil ? 0.92 : 0.72), weight: .light))
                .foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.18)
                .accessibilityLabel("Result").accessibilityValue(previewValue ?? currentDisplay)
                .accessibilityIdentifier("calculator_display")
        }
        .frame(maxWidth: .infinity, minHeight: buttonSize * 1.3, maxHeight: buttonSize * 1.3, alignment: .trailing)
        .contentShape(Rectangle())
        .onTapGesture { editingAction?() }
            .contextMenu {
                Button("Copy", systemImage: "doc.on.doc") { eventCallback(.CopyToClipBoard) }
                Button("Paste", systemImage: "doc.on.clipboard") { eventCallback(.Paste) }
                if let scientificAction { Button("Scientific", action: scientificAction) }
                if let historyAction { Button("History", action: historyAction) }
            }
            .gesture(DragGesture(minimumDistance: 35).onEnded { value in
                if abs(value.translation.width) > abs(value.translation.height) { eventCallback(.Delete) }
            })
    }
}
