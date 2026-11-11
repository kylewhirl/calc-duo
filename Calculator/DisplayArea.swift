// Adapted from bofeiw/ios-calculator-clone-for-ipados (CC0-1.0).
import SwiftUI

enum DisplayAreaEvent { case Delete, CopyToClipBoard, Paste }

struct DisplayArea: View {
    var eventCallback: (DisplayAreaEvent) -> Void
    let currentDisplay: String
    let buttonSize: CGFloat
    var previewValue: String? = nil
    var scientificAction: (() -> Void)? = nil
    var historyAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(currentDisplay)
                .font(.system(size: buttonSize * (previewValue == nil ? 0.92 : 0.66), weight: .light))
                .foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.18)
                .accessibilityLabel("Result").accessibilityValue(currentDisplay)
                .accessibilityIdentifier("calculator_display")
            if let previewValue {
                Text("= " + previewValue)
                    .font(.system(size: buttonSize * 0.28, weight: .light))
                    .foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.18)
                    .accessibilityIdentifier("calculator_preview").accessibilityValue(previewValue)
            }
        }
        .frame(maxWidth: .infinity, minHeight: buttonSize * 1.12, maxHeight: buttonSize * 1.12, alignment: .trailing)
        .contentShape(Rectangle())
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
