// Adapted from bofeiw/ios-calculator-clone-for-ipados (CC0-1.0).
import SwiftUI

struct CalculatorButton: View {
    let key: ButtonType
    let size: CGFloat
    var height: CGFloat? = nil
    var displayLabel: String? = nil
    private var keyHeight: CGFloat { height ?? size }
    let isSelected: Bool
    var action: (ButtonType) -> Void

    private var isUtility: Bool { [.Backspace, .AC, .Percentage].contains(key) }
    private var isOrange: Bool { key.isOperation || key == .Calculate }
    private var background: Color {
        return Color(hex: isOrange ? 0xff9500 : isUtility ? 0x5e5e5e : 0x333333)
    }
    private var foreground: Color { .white }
    private var systemImage: String? {
        switch key {
        case .Plus: return "plus"
        case .Minus: return "minus"
        case .Multiply: return "multiply"
        case .Divide: return "divide"
        case .Calculate: return "equal"
        case .Backspace: return "delete.left"
        case .PlusMinus: return "plus.forwardslash.minus"
        default: return nil
        }
    }
    private var label: String {
        if let displayLabel { return displayLabel }
        if let digit = key.digit { return String(digit) }
        switch key {
        case .AC: return "AC"
        case .Percentage: return "%"
        case .Dot: return "."
        default: return key.symbol
        }
    }
    private var accessibilityName: String {
        switch key {
        case .Backspace: return "Delete last digit"
        case .PlusMinus: return "Change sign"
        case .AC: return "All clear"
        case .Calculate: return "Equals"
        case .Plus: return "Add"
        case .Minus: return "Subtract"
        case .Multiply: return "Multiply"
        case .Divide: return "Divide"
        case .Percentage: return "Percent"
        case .Dot: return "Decimal point"
        default: return label
        }
    }
    var body: some View {
        Button { action(key) } label: {
            Group {
                if let image = systemImage {
                    Image(systemName: image)
                        .font(.system(size: keyHeight * (key == .Backspace ? 0.38 : 0.40), weight: .regular))
                } else {
                    Text(label).font(.system(size: keyHeight * 0.44, weight: .regular))
                }
            }
            .foregroundColor(foreground)
            .frame(width: size, height: keyHeight)
            .background(Capsule().fill(background))
            .overlay(Capsule().strokeBorder(
                LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.02), .white.opacity(0.12)], startPoint: .top, endPoint: .bottom),
                lineWidth: 0.65))
            .contentShape(Capsule())
        }
        .buttonStyle(CalculatorPressStyle())
        .accessibilityLabel(accessibilityName)
        .accessibilityIdentifier("key_" + key.rawValue)
    }
}

private struct CalculatorPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(Capsule().fill(.white.opacity(configuration.isPressed ? 0.22 : 0)))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
