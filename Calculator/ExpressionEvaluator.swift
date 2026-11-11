import Foundation

/// A bounded, pure parser for editable calculator expressions. No code evaluation or model mutation.
/// Implicit multiplication has the same precedence as explicit multiplication; powers associate right.
/// Scientific notation uses `EE`, `E`, or lowercase `e` followed by a signed/unsigned exponent.
/// A bare lowercase `e` is Euler's constant (thus `2e` means 2 × e; `2EE` is incomplete).
/// A direct percentage on the right of +/− is relative to the left operand; ×/÷ use its fraction.
enum ExpressionEvaluator {
    enum EvaluationError: Error, Equatable, LocalizedError {
        case incomplete(String), invalid(String), domain(String), overflow, tooComplex
        var isIncomplete: Bool { if case .incomplete = self { return true }; return false }
        var errorDescription: String? {
            switch self {
            case .incomplete(let detail), .invalid(let detail), .domain(let detail): return detail
            case .overflow: return "Result is outside the supported number range."
            case .tooComplex: return "Expression is too long or deeply nested."
            }
        }
    }
    struct EvaluationResult {
        let value: Double
        /// Plain numeric text suitable for storing or pasting into the calculator.
        let formatted: String
    }
    static func evaluate(_ expression: String, usesDegrees: Bool = true) throws -> Double {
        try evaluateResult(expression, usesDegrees: usesDegrees).value
    }
    static func evaluateResult(_ expression: String, usesDegrees: Bool = true) throws -> EvaluationResult {
        var parser = try Parser(expression, degrees: usesDegrees)
        let result = try parser.parse()
        return EvaluationResult(value: result.double, formatted: result.decimal.map {
            NSDecimalNumber(decimal: $0).stringValue
        } ?? format(result.double))
    }
    static func format(_ value: Double) -> String {
        if value == 0 { return "0" }
        let compact = String(format: "%.15g", locale: Locale(identifier: "en_US_POSIX"), value)
            .lowercased().replacingOccurrences(of: "e+", with: "e")
        // Rounding the largest finite Double to 15 digits would produce an infinite literal.
        if let reparsed = Double(compact), reparsed.isFinite, reparsed != 0 { return compact }
        return String(value).lowercased().replacingOccurrences(of: "e+", with: "e")
    }
    private struct Number {
        let double: Double
        let decimal: Decimal?
        let isPercentage: Bool
        init(_ value: Double, decimal: Decimal? = nil, isPercentage: Bool = false) throws {
            guard !value.isNaN else { throw EvaluationError.domain("Result is not a real number.") }
            guard value.isFinite else { throw EvaluationError.overflow }
            double = value == 0 ? 0 : value
            self.decimal = decimal
            self.isPercentage = isPercentage
        }
        init(literal: String) throws {
            guard let value = Double(literal), value.isFinite else { throw EvaluationError.overflow }
            let mantissa = literal.lowercased().split(separator: "e").first ?? ""
            if value == 0 && mantissa.contains(where: { "123456789".contains($0) }) { throw EvaluationError.overflow }
            let candidate = Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX"))
            let precise = candidate.flatMap { d -> Decimal? in
                guard !d.isNaN, !(d == 0 && value != 0), abs(value) < 1e127 else { return nil }
                return d
            }
            try self.init(value, decimal: precise)
        }
    }
    private enum Token: Equatable {
        case number(String), name(String), op(String), left, right, comma, end
    }
    private struct Parser {
        var tokens: [Token] = []
        var index = 0
        var depth = 0
        let degrees: Bool
        var current: Token { tokens[index] }
        init(_ text: String, degrees: Bool) throws {
            self.degrees = degrees
            guard text.count <= 4096 else { throw EvaluationError.tooComplex }
            // Only fixed calculator aliases are normalized; arbitrary identifiers remain invalid.
            var normalized = text
            for (from, to) in [("sinh⁻¹", "asinh"), ("cosh⁻¹", "acosh"), ("tanh⁻¹", "atanh"),
                               ("sin⁻¹", "asin"), ("cos⁻¹", "acos"), ("tan⁻¹", "atan"),
                               ("log₁₀", "log10"), ("log₂", "log2"), ("xʸ", "^"),
                               ("ʸ√x", "@"), ("yˣ", "~"), ("logᵧ", "#"),
                               ("−", "-"), ("×", "*"), ("÷", "/"), ("π", " pi "),
                               ("√", "sqrt"), ("∛", "cbrt")] {
                normalized = normalized.replacingOccurrences(of: from, with: to)
            }
            let chars = Array(normalized)
            var i = 0
            func digit(_ c: Character) -> Bool { c >= "0" && c <= "9" }
            while i < chars.count {
                let c = chars[i]
                if c.isWhitespace { i += 1; continue }
                if digit(c) || c == "." {
                    let start = i
                    var digits = 0
                    while i < chars.count && digit(chars[i]) { digits += 1; i += 1 }
                    if i < chars.count && chars[i] == "." {
                        i += 1
                        while i < chars.count && digit(chars[i]) { digits += 1; i += 1 }
                    }
                    guard digits > 0 else {
                        if i == chars.count { throw EvaluationError.incomplete("Finish the decimal number.") }
                        throw EvaluationError.invalid("Invalid decimal number.")
                    }
                    var literal = String(chars[start..<i])
                    if i < chars.count && (chars[i] == "e" || chars[i] == "E") {
                        let marker = chars[i]
                        var next = i + 1
                        if next < chars.count && chars[next] == "E" && marker == "E" { next += 1 }
                        let hasSign = next < chars.count && (chars[next] == "+" || chars[next] == "-")
                        let exponentStart = next
                        if hasSign { next += 1 }
                        if marker == "E" || hasSign || (next < chars.count && digit(chars[next])) {
                            guard next < chars.count else { throw EvaluationError.incomplete("Finish the exponent.") }
                            guard digit(chars[next]) else { throw EvaluationError.invalid("Invalid exponent.") }
                            while next < chars.count && digit(chars[next]) { next += 1 }
                            literal += "e" + String(chars[exponentStart..<next]); i = next
                        }
                    }
                    tokens.append(.number(literal)); continue
                }
                if c >= "a" && c <= "z" || c >= "A" && c <= "Z" {
                    let start = i
                    while i < chars.count && ((chars[i] >= "a" && chars[i] <= "z") || (chars[i] >= "A" && chars[i] <= "Z") || digit(chars[i])) { i += 1 }
                    tokens.append(.name(String(chars[start..<i]))); continue
                }
                switch c {
                case "(": tokens.append(.left)
                case ")": tokens.append(.right)
                case ",": tokens.append(.comma)
                case "+", "-", "*", "/", "^", "!", "%", "²", "³", "@", "~", "#": tokens.append(.op(String(c)))
                default: throw EvaluationError.invalid("Unsupported character: \(c)")
                }
                i += 1
            }
            tokens.append(.end)
        }
        mutating func take() -> Token { let result = current; index += 1; return result }
        mutating func parse() throws -> Number {
            let result = try expression()
            guard current == .end else { throw EvaluationError.invalid("Unexpected text after the expression.") }
            return result
        }
        mutating func expression(_ minimum: Int = 0) throws -> Number {
            depth += 1
            defer { depth -= 1 }
            guard depth <= 128 else { throw EvaluationError.tooComplex }
            var left: Number
            switch take() {
            case .number(let text): left = try Number(literal: text)
            case .op(let sign) where sign == "+" || sign == "-":
                let operand = try expression(30)
                left = sign == "+" ? operand : try Number(-operand.double, decimal: operand.decimal.map { -$0 }, isPercentage: operand.isPercentage)
            case .left:
                left = try expression()
                try close()
            case .name(let name):
                if name == "pi" { left = try Number(.pi) }
                else if name == "e" { left = try Number(exp(1)) }
                else {
                    guard Self.functions.contains(name) else { throw EvaluationError.invalid("Unknown function: \(name)") }
                    guard current == .left else {
                        if current == .end { throw EvaluationError.incomplete("Add an argument to \(name).") }
                        throw EvaluationError.invalid("Function arguments require parentheses.")
                    }
                    _ = take()
                    var arguments = [try expression()]
                    while current == .comma { _ = take(); arguments.append(try expression()) }
                    try close()
                    left = try function(name, arguments)
                }
            case .end: throw EvaluationError.incomplete("Add a number or expression.")
            default: throw EvaluationError.invalid("Expected a number or expression.")
            }
            while true {
                if case .op(let op) = current, ["!", "%", "²", "³"].contains(op) {
                    guard 50 >= minimum else { break }
                    _ = take()
                    switch op {
                    case "!": left = try factorial(left.double)
                    case "%":
                        let fraction = try binary(left, "/", Number(literal: "100"))
                        left = try Number(fraction.double, decimal: fraction.decimal, isPercentage: true)
                    case "²": left = try binary(left, "^", Number(literal: "2"))
                    default: left = try binary(left, "^", Number(literal: "3"))
                    }
                    continue
                }
                var op: String, precedence: Int, implicit = false
                switch current {
                case .op(let symbol) where ["+", "-", "*", "/", "^", "@", "~", "#"].contains(symbol):
                    op = symbol; precedence = ["+", "-"].contains(symbol) ? 10 : (["*", "/"].contains(symbol) ? 20 : 40)
                case .left, .name: op = "*"; precedence = 20; implicit = true
                case .number:
                    // A group/constant may multiply a following number, but `1 2` and `1.2.3` are invalid.
                    if case .number = tokens[index - 1] {
                        throw EvaluationError.invalid("Separate numbers with an operator.")
                    }
                    op = "*"; precedence = 20; implicit = true
                default: return left
                }
                guard precedence >= minimum else { break }
                if !implicit { _ = take() }
                let right = try expression(precedence + (precedence == 40 ? 0 : 1))
                left = try binary(left, op, right)
            }
            return left
        }
        mutating func close() throws {
            if current == .end { throw EvaluationError.incomplete("Close the parenthesis.") }
            guard current == .right else { throw EvaluationError.invalid("Expected a closing parenthesis.") }
            _ = take()
        }
        static let functions: Set<String> = ["sin", "cos", "tan", "asin", "acos", "atan", "sinh", "cosh", "tanh", "asinh", "acosh", "atanh", "sqrt", "cbrt", "ln", "log", "log10", "log2", "exp", "pow10", "pow2", "reciprocal", "square", "cube", "factorial", "root", "logBase", "reversePower", "pow", "abs"]
        func function(_ name: String, _ args: [Number]) throws -> Number {
            let two = ["root", "logBase", "reversePower", "pow"].contains(name)
            guard args.count == (two ? 2 : 1) else { throw EvaluationError.invalid("Wrong number of arguments for \(name).") }
            let x = args[0].double
            if two { return try binary(args[0], ["root": "@", "logBase": "#", "reversePower": "~", "pow": "^"][name]!, args[1]) }
            let angle = degrees ? (x.truncatingRemainder(dividingBy: 360) / 180) * Double.pi : x
            let scale = degrees ? 180 / Double.pi : 1
            let value: Double
            switch name {
            case "sin": value = sin(angle)
            case "cos": value = cos(angle)
            case "tan":
                guard abs(cos(angle)) > 1e-14 else { throw EvaluationError.domain("Tangent is undefined at this angle.") }
                value = tan(angle)
            case "asin": value = asin(x) * scale
            case "acos": value = acos(x) * scale
            case "atan": value = atan(x) * scale
            case "sinh": value = sinh(x)
            case "cosh": value = cosh(x)
            case "tanh": value = tanh(x)
            case "asinh": value = asinh(x)
            case "acosh": value = acosh(x)
            case "atanh": value = atanh(x)
            case "sqrt": value = sqrt(x)
            case "cbrt": value = cbrt(x)
            case "ln": value = log(x)
            case "log", "log10": value = log10(x)
            case "log2": value = log2(x)
            case "exp": value = exp(x)
            case "pow10": value = pow(10, x)
            case "pow2": value = pow(2, x)
            case "reciprocal": return try binary(Number(literal: "1"), "/", args[0])
            case "square": return try binary(args[0], "^", Number(literal: "2"))
            case "cube": return try binary(args[0], "^", Number(literal: "3"))
            case "factorial": return try factorial(x)
            default: value = abs(x)
            }
            guard value.isFinite else { throw EvaluationError.domain("\(name) is undefined or out of range for this input.") }
            if value == 0 && ["exp", "pow10", "pow2"].contains(name) { throw EvaluationError.overflow }
            return try Number(value)
        }
        func factorial(_ x: Double) throws -> Number {
            guard x >= 0 else { throw EvaluationError.domain("Factorial requires a nonnegative number.") }
            guard x <= 170.624 else { throw EvaluationError.overflow }
            if x.rounded() == x {
                return try Number(x < 2 ? 1 : (2...Int(x)).reduce(1.0) { $0 * Double($1) })
            }
            return try Number(tgamma(x + 1))
        }
        func binary(_ a: Number, _ op: String, _ operand: Number) throws -> Number {
            // Parentheses and a unary sign preserve a direct percent. Other operations consume it.
            let b = operand.isPercentage && ["+", "-"].contains(op)
                ? try binary(a, "*", operand) : operand
            let x = a.double, y = b.double
            if ["+", "-", "*", "/"].contains(op), var ad = a.decimal, var bd = b.decimal {
                if op == "/" && y == 0 { throw EvaluationError.domain("Cannot divide by zero.") }
                var result = Decimal()
                let status: Decimal.CalculationError
                switch op {
                case "+": status = NSDecimalAdd(&result, &ad, &bd, .plain)
                case "-": status = NSDecimalSubtract(&result, &ad, &bd, .plain)
                case "*": status = NSDecimalMultiply(&result, &ad, &bd, .plain)
                default: status = NSDecimalDivide(&result, &ad, &bd, .plain)
                }
                if status == .noError || status == .lossOfPrecision {
                    let value = NSDecimalNumber(decimal: result).doubleValue
                    if value.isFinite && !(value == 0 && x != 0 && y != 0 && ["*", "/"].contains(op)) {
                        return try Number(value, decimal: result)
                    }
                }
            }
            let value: Double
            switch op {
            case "+": value = x + y
            case "-": value = x - y
            case "*": value = x * y
            case "/":
                guard y != 0 else { throw EvaluationError.domain("Cannot divide by zero.") }
                value = x / y
            case "^": value = pow(x, y)
            case "~": value = pow(y, x)
            case "#":
                guard x > 0, y > 0, y != 1 else { throw EvaluationError.domain("Logarithm requires a positive input and base other than 1.") }
                value = log(x) / log(y)
            default:
                guard y != 0 else { throw EvaluationError.domain("Root degree cannot be zero.") }
                if x < 0 {
                    guard y.rounded() == y, y.truncatingRemainder(dividingBy: 2) != 0 else { throw EvaluationError.domain("This root has no real result.") }
                    value = -pow(-x, 1 / y)
                } else { value = pow(x, 1 / y) }
            }
            if value == 0 && x != 0 && y != 0 && ["*", "/", "^", "~", "@"].contains(op) { throw EvaluationError.overflow }
            return try Number(value)
        }
    }
}
