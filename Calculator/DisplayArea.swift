// Adapted from bofeiw/ios-calculator-clone-for-ipados (CC0-1.0).
import SwiftUI

enum DisplayAreaEvent { case Delete, CopyToClipBoard, Paste }

private struct DisplayLeadingOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Keeps the expression readable at full size. Scrolling never deletes input.
struct CalculatorDisplayLine: View {
    let text: String
    let fontSize: CGFloat
    let identifier: String
    var label = "Expression"
    var secondary = false
    @State private var hasLeadingOverflow = false
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scroll in
                ScrollView(.horizontal) {
                    Text(text).font(.system(size: fontSize, weight: .light))
                        .foregroundStyle(secondary ? .secondary : .primary)
                        .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: geometry.size.width, alignment: .trailing)
                        .background {
                            GeometryReader { content in
                                Color.clear.preference(key: DisplayLeadingOffsetKey.self,
                                    value: content.frame(in: .named(identifier)).minX)
                            }
                        }
                        .id("end")
                        .accessibilityIdentifier(identifier).accessibilityLabel(label).accessibilityValue(text)
                }
                .accessibilityIdentifier(identifier + "_viewport")
                .scrollIndicators(.hidden)
                .coordinateSpace(name: identifier)
                .onPreferenceChange(DisplayLeadingOffsetKey.self) { hasLeadingOverflow = $0 < -1 }
                .mask {
                    if hasLeadingOverflow {
                        HStack(spacing: 0) {
                            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 24)
                            Rectangle().fill(.black)
                        }
                    } else { Rectangle().fill(.black) }
                }
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
