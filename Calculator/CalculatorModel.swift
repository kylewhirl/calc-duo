// Adapted from bofeiw/ios-calculator-clone-for-ipados (CC0-1.0).
import Foundation

enum ButtonType: String, CaseIterable {
    case Plus, Minus, Multiply, Divide, Power, Root, ReversePower, LogBase
    case Number0, Number1, Number2, Number3, Number4, Number5, Number6, Number7, Number8, Number9
    case Dot, Calculate, AC, PlusMinus, Percentage, Backspace

    var digit: Int? {
        guard rawValue.hasPrefix("Number") else { return nil }
        return Int(rawValue.dropFirst(6))
    }
    var symbol: String {
        switch self {
        case .Plus: return "+"
        case .Minus: return "−"
        case .Multiply: return "×"
        case .Divide: return "÷"
        case .Power: return "xʸ"
        case .Root: return "ʸ√x"
        case .ReversePower: return "yˣ"
        case .LogBase: return "logᵧ"
        default: return ""
        }
    }
    var isOperation: Bool { [.Plus, .Minus, .Multiply, .Divide, .Power, .Root, .ReversePower, .LogBase].contains(self) }
}

enum ScientificFunction: String, CaseIterable {
    case square, cube, squareRoot, cubeRoot, reciprocal
    case sin, cos, tan, asin, acos, atan, ln, log10, exp, pow10
    case factorial, pi, e, random
    case pow2, log2, sinh, cosh, tanh, asinh, acosh, atanh
    var expressionLabel: String {
        switch self {
        case .squareRoot: return "√"
        case .cubeRoot: return "∛"
        case .reciprocal: return "1/"
        case .asin: return "sin⁻¹"
        case .acos: return "cos⁻¹"
        case .atan: return "tan⁻¹"
        case .asinh: return "sinh⁻¹"
        case .acosh: return "cosh⁻¹"
        case .atanh: return "tanh⁻¹"
        case .log10: return "log₁₀"
        case .log2: return "log₂"
        case .exp: return "e^"
        case .pow10: return "10^"
        case .pow2: return "2^"
        default: return rawValue
        }
    }
}

/// Expression calculator with standard precedence. Decimal avoids 0.1 + 0.2 artifacts.
struct CalculatorModel {
    private(set) var entry = "0"
    private(set) var completedExpression: String?
    private(set) var selectedOperator: ButtonType?
    private var accumulator: String?
    private var repeatOperator: ButtonType?
    private var repeatOperand: String?
    private var startsNewEntry = false
    private var replaceEntryOnDigit = false
    var usesDegrees = true
    private(set) var isError = false
    private let inputLimit = 15
    private var value: String { normalizedEntry }
    private var normalizedEntry: String {
        if entry.hasSuffix("e") || entry.hasSuffix("e-") || entry.hasSuffix("e+") { return entry + "0" }
        return entry
    }
    var isScientificMode = false {
        didSet {
            if isScientificMode, let left = accumulator, let operation = selectedOperator, frame.operations.isEmpty {
                frame.values = [left]
                frame.operations = [operation]
                frame.expression = basicExpression
                basicExpression = ""
                accumulator = nil
            }
        }
    }
    private var memory = "0"
    var hasMemory: Bool { (Double(memory) ?? 0) != 0 }
    private struct Frame { var values: [String] = []; var operations: [ButtonType] = []; var expression = ""; var function: ScientificFunction? }
    private var frame = Frame()
    private var parents: [Frame] = []
    var parenthesisDepth: Int { parents.count }
    private var groupJustClosed = false
    private var entryIsEmpty = true
    struct HistoryEntry: Identifiable, Codable {
        let id: UUID
        init(expression: String, result: String) {
            id = UUID(); self.expression = expression; self.result = result
        }
        let expression: String
        let result: String
        var date: Date? = Date()
    }
    private(set) var history: [HistoryEntry] = []
    private var operandExpression: String?
    private var basicExpression = ""
    var expression: String {
        let frames = parents + [frame]
        let prefix = parents.indices.map { index in
            parents[index].expression + (frames[index + 1].function?.expressionLabel ?? "") + "("
        }.joined() + frame.expression
        let operand = startsNewEntry && (selectedOperator != nil || !parents.isEmpty) ? "" : (operandExpression ?? entry)
        return (prefix.isEmpty ? basicExpression : prefix) + operand
    }
    var previewValue: String? {
        guard !isError, !startsNewEntry, selectedOperator != nil || !parents.isEmpty else { return nil }
        var copy = self
        copy.performCalculate()
        return copy.isError ? nil : copy.displayedValue
    }
    var displayExpression: String? {
        if expression != entry { return expression }
        if startsNewEntry, let last = history.first, last.result == entry { return last.expression }
        return nil
    }
    var primaryDisplay: String {
        if completedExpression != nil || isError { return displayedValue }
        return expression == entry ? displayedValue : expression
    }
    var livePreview: String? {
        guard completedExpression == nil, !isError else { return nil }
        return previewValue ?? (operandExpression != nil ? displayedValue : nil)
    }
    var editableExpression: String {
        if startsNewEntry, selectedOperator == nil, parents.isEmpty, frame.operations.isEmpty,
           let last = history.first, last.result == entry { return last.expression }
        return expression
    }
    mutating func commitEditedExpression(_ expression: String, result: Double) {
        guard let normalized = scientificDecimal(result) else { fail(); return }
        onAC()
        setValue(normalized)
        startsNewEntry = true
        completedExpression = expression
        history.insert(HistoryEntry(expression: expression, result: entry), at: 0)
        if history.count > 100 { history.removeLast(history.count - 100) }
    }
    mutating func restoreHistory(_ id: UUID) {
        guard let item = history.first(where: { $0.id == id }) else { return }
        onAC()
        entry = item.result
        replaceEntryOnDigit = true
    }
    mutating func deleteHistory(_ id: UUID) { history.removeAll { $0.id == id } }
    mutating func clearHistory() { history.removeAll() }
    mutating func loadHistory(_ entries: [HistoryEntry]) {
        history = Array(entries.filter { Double($0.result)?.isFinite == true }.prefix(100))
    }
    var shouldClearEntry: Bool { !startsNewEntry && entry != "0" }
    var canClearEntry: Bool { entry != "0" || isError }


    var displayedValue: String {
        guard !isError else { return "Error" }
        let number = computedValue
        if number != 0 && (abs(number) >= 1e15 || abs(number) < 1e-9) {
            let compact = String(format: "%.10g", locale: Locale(identifier: "en_US_POSIX"), number)
                .lowercased().replacingOccurrences(of: "e+", with: "e")
            return Double(compact)?.isFinite == true ? compact : String(number)
        }
        let parts = entry.split(separator: ".", omittingEmptySubsequences: false)
        let integer = String(parts.first ?? "0")
        guard !integer.lowercased().contains("e") else { return entry }
        let negative = integer.hasPrefix("-")
        let digits = negative ? String(integer.dropFirst()) : integer
        let grouped = String(digits.reversed()).enumerated().map { index, char in
            (index > 0 && index % 3 == 0 ? "," : "") + String(char)
        }.joined()
        return (negative ? "−" : "") + String(grouped.reversed()) + (parts.count > 1 ? "." + parts[1] : "")
    }
    var computedValue: Double { Double(normalizedEntry) ?? 0 }

    mutating func onTypeNumber(_ number: Int) {
        completedExpression = nil
        guard (0...9).contains(number) else { return }
        prepareEntry()
        entryIsEmpty = false
        if let index = entry.firstIndex(of: "e") {
            let exponent = entry[entry.index(after: index)...].filter { $0.isNumber }
            guard exponent.count < 3 else { return }
            entry += String(number)
            return
        }
        guard entry.filter({ $0.isNumber }).count < inputLimit else { return }
        if entry == "0" { entry = String(number) }
        else if entry == "-0" { entry = "-" + String(number) }
        else { entry += String(number) }
    }
    mutating func onTypeDot() {
        completedExpression = nil
        prepareEntry()
        entryIsEmpty = false
        if !entry.contains(".") && !entry.contains("e") { entry += "." }
    }
    mutating func onAC() {
        let mode = usesDegrees, scientific = isScientificMode, savedMemory = memory
        let savedHistory = history
        self = CalculatorModel()
        usesDegrees = mode
        isScientificMode = scientific
        memory = savedMemory
        history = savedHistory
    }

    mutating func onScientific(_ function: ScientificFunction) {
        completedExpression = nil
        if isError {
            guard [.pi, .e, .random].contains(function) else { return }
            onAC()
        }
        let prefixFunctions: [ScientificFunction] = [.squareRoot, .cubeRoot, .reciprocal,
            .sin, .cos, .tan, .asin, .acos, .atan, .ln, .log10, .exp, .pow10,
            .pow2, .log2, .sinh, .cosh, .tanh, .asinh, .acosh, .atanh]
        if isScientificMode && (entryIsEmpty || (startsNewEntry && selectedOperator != nil)) && prefixFunctions.contains(function) {
            onOpenParenthesis()
            frame.function = function
            return
        }
        entryIsEmpty = false
        let inputExpression = operandExpression ?? entry
        let x = computedValue
        let angle = usesDegrees ? x * .pi / 180 : x
        let inverseScale = usesDegrees ? 180 / Double.pi : 1
        let result: Double
        switch function {
        case .pow2: result = pow(2, x)
        case .log2: result = log2(x)
        case .sinh: result = sinh(x)
        case .cosh: result = cosh(x)
        case .tanh: result = tanh(x)
        case .asinh: result = asinh(x)
        case .acosh: result = acosh(x)
        case .atanh: result = atanh(x)
        case .square: result = x * x
        case .cube: result = x * x * x
        case .squareRoot: result = sqrt(x)
        case .cubeRoot: result = cbrt(x)
        case .reciprocal: result = 1 / x
        case .sin: result = sin(angle)
        case .cos: result = cos(angle)
        case .tan:
            guard abs(cos(angle)) > 1e-14 else { fail(); return }
            result = tan(angle)
        case .asin: result = asin(x) * inverseScale
        case .acos: result = acos(x) * inverseScale
        case .atan: result = atan(x) * inverseScale
        case .ln: result = log(x)
        case .log10: result = log10(x)
        case .exp: result = exp(x)
        case .pow10: result = pow(10, x)
        case .factorial:
            guard x >= 0, x <= 170 else { fail(); return }
            if x.rounded() != x { result = tgamma(x + 1) }
            else { result = x < 2 ? 1 : (2...Int(x)).reduce(1.0) { $0 * Double($1) } }
        case .pi: result = .pi
        case .e: result = exp(1)
        case .random: result = Double.random(in: 0..<1)
        }
        guard !(result == 0 && [.exp, .pow10, .pow2].contains(function)),
              let decimal = scientificDecimal(result) else { fail(); return }
        setValue(decimal)
        switch function {
        case .pi: operandExpression = "π"
        case .e: operandExpression = "e"
        case .random: operandExpression = entry
        case .factorial: operandExpression = "(" + inputExpression + ")!"
        case .square: operandExpression = "(" + inputExpression + ")²"
        case .cube: operandExpression = "(" + inputExpression + ")³"
        default: operandExpression = function.expressionLabel + "(" + inputExpression + ")"
        }
        startsNewEntry = false
        replaceEntryOnDigit = true
        repeatOperator = nil
        repeatOperand = nil
    }

    /// Keep full Double range for scientific results, Decimal arithmetic for ordinary entries.
    private func scientificDecimal(_ result: Double) -> String? {
        guard result.isFinite else { return nil }
        let rounded = String(format: "%.15g", locale: Locale(identifier: "en_US_POSIX"), result)
        return Double(rounded)?.isFinite == true ? rounded : String(result)
    }

    mutating func onSelectOperator(_ operation: ButtonType) {
        completedExpression = nil
        guard operation.isOperation, !isError else { return }
        // Basic and scientific layouts share the same expression evaluator so the
        // visible expression, editable expression, preview and result agree.
        selectScientificOperator(operation)
    }

    mutating func onCalculate() {
        // Clearing an operand leaves an incomplete expression, not an implicit zero.
        guard !(entryIsEmpty && (selectedOperator != nil || !parents.isEmpty)) else { return }
        let original: String
        if selectedOperator == nil, parents.isEmpty, frame.operations.isEmpty,
           let operation = repeatOperator, let right = repeatOperand {
            original = entry + operation.symbol + right
        } else { original = expression }
        let shouldRecord = !isError
        performCalculate()
        if shouldRecord && !isError {
            completedExpression = original
            history.insert(HistoryEntry(expression: original, result: entry), at: 0)
            if history.count > 100 { history.removeLast(history.count - 100) }
        }
        operandExpression = nil
        basicExpression = ""
        groupJustClosed = false
    }
    private mutating func performCalculate() {
        guard !isError, !(entryIsEmpty && (selectedOperator != nil || !parents.isEmpty)) else { return }
        guard computedValue.isFinite else { fail(); return }
        if !parents.isEmpty || !frame.operations.isEmpty {
            let hadParentheses = !parents.isEmpty
            while !parents.isEmpty { onCloseParenthesis(); if isError { return } }
            if !frame.operations.isEmpty {
                frame.values.append(value)
                while !frame.operations.isEmpty { guard reduceFrame() else { return } }
                if let result = frame.values.last { setValue(result) }
                frame = Frame()
                selectedOperator = nil
                startsNewEntry = true
                return
            }
            if hadParentheses {
                frame = Frame()
                selectedOperator = nil
                startsNewEntry = true
                return
            }
        }
        if let operation = selectedOperator, let left = accumulator {
            let right = startsNewEntry ? left : value
            guard let result = calculate(left, operation, right) else { fail(); return }
            setValue(result)
            repeatOperator = operation
            repeatOperand = right
            accumulator = nil
            selectedOperator = nil
        } else if let operation = repeatOperator, let right = repeatOperand {
            guard let result = calculate(value, operation, right) else { fail(); return }
            setValue(result)
        }
        startsNewEntry = true
    }
    mutating func onPlusMinus() {
        completedExpression = nil
        guard !isError else { return }
        operandExpression = nil
        if let index = entry.firstIndex(of: "e") {
            let next = entry.index(after: index)
            if entry[next...].hasPrefix("-") { entry.remove(at: next) }
            else { entry.insert("-", at: next) }
            return
        }
        // Sign modifies the operand being entered, not the stored left operand.
        if startsNewEntry && selectedOperator != nil { entry = "0" }
        if entry.hasPrefix("-") { entry.removeFirst() } else { entry = "-" + entry }
        startsNewEntry = false
    }
    mutating func onPercentage() {
        completedExpression = nil
        guard !isError else { return }
        operandExpression = nil
        guard var result = calculate(value, .Divide, "100") else { fail(); return }
        let left = frame.values.last ?? accumulator
        if let operation = selectedOperator, [.Plus, .Minus].contains(operation), let left {
            guard let relative = calculate(left, .Multiply, result) else { fail(); return }
            result = relative
        }
        setValue(result)
        startsNewEntry = false
    }
    mutating func onDelete() {
        completedExpression = nil
        replaceEntryOnDigit = false
        operandExpression = nil
        if isError { onAC(); return }
        if startsNewEntry && selectedOperator != nil { return }
        if entry.lowercased().contains("e") {
            entry.removeLast()
            if entry.hasSuffix("e") { entry.removeLast() }
        } else {
            entry.removeLast()
            if entry.isEmpty || entry == "-" { entry = "0" }
        }
        startsNewEntry = false
        repeatOperator = nil
        repeatOperand = nil
    }
    mutating func onPaste(_ content: String) {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "−", with: "-")
        // Reject partial parses, NaN, infinity, and arbitrary pasted text.
        guard normalized.range(of: #"^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$"#, options: .regularExpression) != nil,
              let parsed = Double(normalized), parsed.isFinite else { return }
        completedExpression = nil
        if isError { onAC() }
        operandExpression = nil
        entryIsEmpty = false
        if let decimal = decimalValue(normalized) { setValue(NSDecimalNumber(decimal: decimal).stringValue) }
        else { setValue(normalized) }
        replaceEntryOnDigit = false
        startsNewEntry = false
        repeatOperator = nil
        repeatOperand = nil
    }
    private mutating func prepareEntry() {
        if isError { onAC() }
        operandExpression = nil
        if startsNewEntry || replaceEntryOnDigit { entry = "0"; startsNewEntry = false; replaceEntryOnDigit = false }
        if selectedOperator == nil { basicExpression = "" }
    }
    private mutating func setValue(_ value: String) {
        guard let number = Double(value), number.isFinite else { fail(); return }
        entry = value == "-0" ? "0" : value
    }
    private mutating func fail() {
        onAC()
        isError = true
        startsNewEntry = true
    }
    private func decimalValue(_ text: String) -> Decimal? {
        guard let d = Double(text), d.isFinite, d == 0 || (abs(d) >= 1e-127 && abs(d) < 1e127),
              let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN else { return nil }
        return value
    }
    private func calculate(_ lhs: String, _ operation: ButtonType, _ rhs: String) -> String? {
        guard let x = Double(lhs), let y = Double(rhs), x.isFinite, y.isFinite else { return nil }
        if [.Plus, .Minus, .Multiply, .Divide].contains(operation), let a = decimalValue(lhs), let b = decimalValue(rhs) {
            var result: Decimal
            switch operation {
            case .Plus: result = a + b
            case .Minus: result = a - b
            case .Multiply: result = a * b
            default: guard b != 0 else { return nil }; result = a / b
            }
            if !result.isNaN, !(result == 0 && x != 0 && y != 0 && [.Multiply, .Divide].contains(operation)) {
                return NSDecimalNumber(decimal: result).stringValue
            }
        }
        let result: Double
        switch operation {
        case .Plus: result = x + y
        case .Minus: result = x - y
        case .Multiply: result = x * y
        case .Divide: result = x / y
        case .Power: result = pow(x, y)
        case .ReversePower: result = pow(y, x)
        case .LogBase:
            guard x > 0, y > 0, y != 1 else { return nil }
            result = log(x) / log(y)
        case .Root:
            guard y != 0 else { return nil }
            if x < 0 {
                guard y.rounded() == y, y.truncatingRemainder(dividingBy: 2) != 0 else { return nil }
                result = -pow(-x, 1 / y)
            } else { result = pow(x, 1 / y) }
        default: return nil
        }
        guard !(result == 0 && x != 0 && y != 0 && [.Multiply, .Divide, .Power, .ReversePower, .Root].contains(operation)) else { return nil }
        return scientificDecimal(result)
    }

    mutating func onExponent() {
        completedExpression = nil
        guard !isError else { return }
        if startsNewEntry && selectedOperator != nil { entry = "1" }
        guard !entry.lowercased().contains("e") else { return }
        entry += "e"
        startsNewEntry = false
        replaceEntryOnDigit = false
    }
    mutating func onClearEntry() {
        completedExpression = nil
        if isError { onAC(); return }
        entry = "0"
        operandExpression = nil
        startsNewEntry = selectedOperator != nil || !parents.isEmpty
        entryIsEmpty = true
        replaceEntryOnDigit = false
        repeatOperator = nil
        repeatOperand = nil
    }
    mutating func onMemoryClear() { memory = "0" }
    mutating func onMemoryAdd() { updateMemory(.Plus) }
    mutating func onMemorySubtract() { updateMemory(.Minus) }
    private mutating func updateMemory(_ operation: ButtonType) {
        guard !isError else { return }
        var displayed = value
        if isScientificMode && !startsNewEntry && (selectedOperator != nil || !parents.isEmpty) {
            var preview = self
            preview.performCalculate()
            if !preview.isError { displayed = preview.value }
        }
        guard let result = calculate(memory, operation, displayed) else { fail(); return }
        memory = result
        replaceEntryOnDigit = true
    }
    mutating func onMemoryRecall() {
        completedExpression = nil
        if isError { onAC() }
        entry = memory
        entryIsEmpty = false
        operandExpression = nil
        startsNewEntry = false
        replaceEntryOnDigit = true
        repeatOperator = nil
        repeatOperand = nil
    }
    private func precedence(_ operation: ButtonType) -> Int {
        switch operation {
        case .Plus, .Minus: return 1
        case .Multiply, .Divide: return 2
        default: return 3
        }
    }
    private mutating func reduceFrame() -> Bool {
        guard let operation = frame.operations.popLast(), frame.values.count >= 2 else { fail(); return false }
        let right = frame.values.removeLast(), left = frame.values.removeLast()
        guard let result = calculate(left, operation, right) else { fail(); return false }
        frame.values.append(result)
        repeatOperator = operation
        repeatOperand = right
        return true
    }
    private mutating func selectScientificOperator(_ operation: ButtonType) {
        if startsNewEntry && !frame.operations.isEmpty {
            let previous = frame.operations[frame.operations.count - 1]
            frame.expression = String(frame.expression.dropLast(previous.symbol.count)) + operation.symbol
            frame.operations.removeLast()
            while let previous = frame.operations.last, precedence(previous) >= precedence(operation) {
                guard reduceFrame() else { return }
            }
            frame.operations.append(operation)
        } else {
            frame.expression += (operandExpression ?? entry) + operation.symbol
            frame.values.append(value)
            while let previous = frame.operations.last, precedence(previous) >= precedence(operation) {
                guard reduceFrame() else { return }
            }
            frame.operations.append(operation)
            if let interim = frame.values.last { setValue(interim) }
        }
        selectedOperator = operation
        operandExpression = nil
        startsNewEntry = true
        replaceEntryOnDigit = false
        groupJustClosed = false
        repeatOperator = nil
        repeatOperand = nil
    }
    mutating func onOpenParenthesis() {
        completedExpression = nil
        guard !isError else { return }
        // Adjacent completed operands imply multiplication.
        if !startsNewEntry && (entry != "0" || groupJustClosed) { selectScientificOperator(.Multiply) }
        parents.append(frame)
        operandExpression = nil
        frame = Frame()
        entryIsEmpty = true
        selectedOperator = nil
        entry = "0"
        startsNewEntry = true
        replaceEntryOnDigit = false
        groupJustClosed = false
    }
    mutating func onCloseParenthesis() {
        completedExpression = nil
        guard !isError, !parents.isEmpty, !entryIsEmpty else { return }
        let innerExpression = frame.expression + (operandExpression ?? entry)
        let function = frame.function
        frame.values.append(value)
        while !frame.operations.isEmpty { guard reduceFrame() else { return } }
        setValue(frame.values.last ?? "0")
        startsNewEntry = false
        entryIsEmpty = false
        if let function {
            onScientific(function)
            guard !isError else { return }
        }
        let result = value
        frame = parents.removeLast()
        setValue(result)
        operandExpression = (function?.expressionLabel ?? "") + "(" + innerExpression + ")"
        selectedOperator = frame.operations.last
        startsNewEntry = false
        replaceEntryOnDigit = true
        groupJustClosed = true
    }
}
