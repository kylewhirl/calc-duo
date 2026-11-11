// Adapted from bofeiw/ios-calculator-clone-for-ipados (CC0-1.0).
import SwiftUI

enum DisplayAreaEvent { case Delete, CopyToClipBoard, Paste }

/// Keeps the expression readable at full size. Scrolling never deletes input.
struct CalculatorDisplayLine: View {
    let text: String
    let fontSize: CGFloat
    let identifier: String
    var label = "Expression"
    var secondary = false
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scroll in
                ScrollView(.horizontal) {
                    Text(text).font(.system(size: fontSize, weight: .light))
                        .foregroundStyle(secondary ? .secondary : .primary)
                        .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: geometry.size.width, alignment: .trailing)
                        .id("end")
                        .accessibilityIdentifier(identifier).accessibilityLabel(label).accessibilityValue(text)
                }
                .scrollIndicators(.hidden)
                .defaultScrollAnchor(.trailing)
                .onChange(of: text) { _, _ in scroll.scrollTo("end", anchor: .trailing) }
            }
        }.frame(height: fontSize * 1.2)
    }
}

struct DisplayArea: View {
    var eventCallback: (DisplayAreaEvent) -> Void
    let currentDisplay: String
    let buttonSize: CGFloat
    var previewValue: String? = nil
    var expression: String? = nil
    var displayHeight: CGFloat? = nil
    var editingAction: (() -> Void)? = nil
    var scientificAction: (() -> Void)? = nil
    var historyAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if let expression {
                CalculatorDisplayLine(text: expression, fontSize: buttonSize * 0.25,
                                      identifier: "calculator_expression", secondary: true)
            }
            CalculatorDisplayLine(text: currentDisplay, fontSize: buttonSize * 0.78,
                                  identifier: "calculator_display", label: expression == nil ? "Expression" : "Result")
            if expression == nil, let previewValue {
                Text("= " + previewValue).font(.system(size: buttonSize * 0.25, weight: .light))
                    .foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.2)
                    .accessibilityIdentifier("calculator_preview")
            }
        }
        .frame(maxWidth: .infinity, minHeight: displayHeight ?? buttonSize * 1.25, maxHeight: displayHeight ?? buttonSize * 1.25, alignment: .bottomTrailing)
        .contentShape(Rectangle())
        .onTapGesture { editingAction?() }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { eventCallback(.CopyToClipBoard) }
            Button("Paste", systemImage: "doc.on.clipboard") { eventCallback(.Paste) }
            if let scientificAction { Button("Scientific", action: scientificAction) }
            if let historyAction { Button("History", action: historyAction) }
        }
    }
}
