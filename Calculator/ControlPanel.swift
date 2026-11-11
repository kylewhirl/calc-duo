// Adapted from bofeiw/ios-calculator-clone-for-ipados (CC0-1.0).
import SwiftUI

/// Maximize keys within the safe viewport while retaining all rows and display.
struct CalculatorLayout {
    let buttonSize: CGFloat
    let buttonHeight: CGFloat
    let scientificButtonWidth: CGFloat
    let gap: CGFloat
    let scientific: Bool
    let stacked: Bool
    let displayHeight: CGFloat
    var width: CGFloat { 4 * buttonSize + 3 * gap }
    var height: CGFloat { 5 * buttonHeight + 4 * gap }
    var scientificWidth: CGFloat { 6 * scientificButtonWidth + 5 * gap }
    var panelWidth: CGFloat { scientific ? (stacked ? width : width + gap + scientificWidth) : width }
    var keypadHeight: CGFloat { scientific && stacked ? height * 2 + gap : height }
    var contentHeight: CGFloat { displayHeight + 1.5 * gap + keypadHeight }
    static let edgePadding: CGFloat = 16
    static let bottomPadding: CGFloat = 4
    static func usesScientificMode(_ size: CGSize) -> Bool { size.width > size.height || size.width >= 600 }
    init(availableSize: CGSize, scientific: Bool = false, converting: Bool = false) {
        self.scientific = scientific
        let width = max(availableSize.width, 1), height = max(availableSize.height, 1)
        stacked = scientific && width <= height
        let referenceWidth = min(width, height, 650)
        let compact = height / width < 1.65
        let desiredGap = compact ? min(6, referenceWidth * 30 / 1398) : 8
        gap = min(desiredGap, max(0, (width - 32) / 30))
        if scientific {
            let usableWidth = max(0, width - 32)
            let columns: CGFloat = stacked ? 6 : 10
            scientificButtonWidth = max(0, (usableWidth - (columns - 1) * gap) / columns)
            buttonSize = stacked ? max(0, (usableWidth - 3 * gap) / 4) : scientificButtonWidth
            let rows: CGFloat = stacked ? 10 : 5
            let room = max(0, height - Self.bottomPadding - 52)
            buttonHeight = max(0, min(scientificButtonWidth, (room - (rows + 0.5) * gap) / (rows + 2)))
            displayHeight = buttonHeight * 2
        } else {
            let desired = (width - 32 - 3 * gap) / 4
            let displayRatio: CGFloat = converting ? 2.2 : 1.25
            buttonSize = max(0, min(desired, (width - 32 - 3 * gap) / 4, (height - Self.bottomPadding - 52 - 5.5 * gap) / (5 + displayRatio)))
            buttonHeight = buttonSize
            scientificButtonWidth = buttonSize
            displayHeight = buttonSize * displayRatio
        }
    }
}

extension Color {
    init(hex: Int) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255, opacity: 1)
    }
}

struct ControlPanel: View {
    let layout: CalculatorLayout
    let selectedOperator: ButtonType?
    var clearLabel = "AC"
    var clickCallback: (ButtonType) -> Void

    static let rows: [[ButtonType]] = [
        [.Backspace, .AC, .Percentage, .Divide],
        [.Number7, .Number8, .Number9, .Multiply],
        [.Number4, .Number5, .Number6, .Minus],
        [.Number1, .Number2, .Number3, .Plus],
        [.PlusMinus, .Number0, .Dot, .Calculate]
    ]

    var body: some View {
        VStack(spacing: layout.gap) {
            ForEach(Self.rows.indices, id: \.self) { row in
                HStack(spacing: layout.gap) {
                    ForEach(Self.rows[row], id: \.self) { key in
                        CalculatorButton(key: key, size: layout.buttonSize, height: layout.buttonHeight, displayLabel: key == .AC ? clearLabel : nil,
                                         isSelected: selectedOperator == key,
                                         action: clickCallback)
                    }
                }
            }
        }
    }
}
