// Adapted from bofeiw/ios-calculator-clone-for-ipados (CC0-1.0).
import SwiftUI

enum DisplayAreaEvent { case Delete, CopyToClipBoard, Paste }

struct DisplayArea: View {
    var eventCallback: (DisplayAreaEvent) -> Void
    let currentDisplay: String
    let buttonSize: CGFloat

    var body: some View {
        Text(currentDisplay)
            .font(.system(size: buttonSize * 0.92, weight: .light))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.18)
            .frame(maxWidth: .infinity, minHeight: buttonSize * 1.12, alignment: .trailing)
            .contentShape(Rectangle())
            .accessibilityLabel("Result")
            .accessibilityValue(currentDisplay)
            .accessibilityIdentifier("calculator_display")
            .contextMenu {
                Button("Copy", systemImage: "doc.on.doc") { eventCallback(.CopyToClipBoard) }
                Button("Paste", systemImage: "doc.on.clipboard") { eventCallback(.Paste) }
            }
            .gesture(DragGesture(minimumDistance: 35).onEnded { value in
                if abs(value.translation.width) > abs(value.translation.height) { eventCallback(.Delete) }
            })
    }
}
