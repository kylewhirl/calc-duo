import XCTest
@testable import Calculator

final class CalculatorTests: XCTestCase {
    private func enter(_ text: String, into model: inout CalculatorModel) {
        for char in text {
            if char == "." { model.onTypeDot() }
            else if let digit = char.wholeNumberValue { model.onTypeNumber(digit) }
        }
    }
    func testAllFourOperations() {
        for (operation, expected) in [(ButtonType.Plus, 15.0), (.Minus, 9.0), (.Multiply, 36.0), (.Divide, 4.0)] {
            var model = CalculatorModel()
            enter("12", into: &model); model.onSelectOperator(operation); enter("3", into: &model); model.onCalculate()
            XCTAssertEqual(model.computedValue, expected)
        }
    }
    func testZeroIsAnOperand() {
        var model = CalculatorModel()
        enter("7", into: &model); model.onSelectOperator(.Multiply); enter("0", into: &model); model.onCalculate()
        XCTAssertEqual(model.displayedValue, "0")
        model.onSelectOperator(.Plus); enter("3", into: &model); model.onCalculate()
        XCTAssertEqual(model.displayedValue, "3")
    }
    func testSignChangesCurrentOperand() {
        var model = CalculatorModel()
        enter("10", into: &model); model.onSelectOperator(.Plus); enter("2", into: &model); model.onPlusMinus(); model.onCalculate()
        XCTAssertEqual(model.displayedValue, "8")
        model.onAC(); enter("5", into: &model); model.onPlusMinus(); model.onSelectOperator(.Multiply); enter("3", into: &model); model.onCalculate()
        XCTAssertEqual(model.displayedValue, "−15")
    }
    func testExpressionPrecedenceAndOperatorReplacement() {
        var model = CalculatorModel()
        enter("2", into: &model); model.onSelectOperator(.Plus); enter("3", into: &model); model.onSelectOperator(.Multiply); enter("4", into: &model); model.onCalculate()
        XCTAssertEqual(model.displayedValue, "14")
        XCTAssertEqual(model.completedExpression, "2+3×4")
        model.onAC(); enter("8", into: &model); model.onSelectOperator(.Plus); model.onSelectOperator(.Divide); enter("2", into: &model); model.onCalculate()
        XCTAssertEqual(model.displayedValue, "4")
    }
    func testRepeatedEqualsAndFreshInput() {
        var model = CalculatorModel()
        enter("2", into: &model); model.onSelectOperator(.Plus); enter("3", into: &model); model.onCalculate(); model.onCalculate()
        XCTAssertEqual(model.displayedValue, "8")
        enter("9", into: &model); model.onCalculate()
        XCTAssertEqual(model.displayedValue, "12")
        XCTAssertEqual(model.completedExpression, "9+3")
    }
    func testRejectedPastePreservesCompletedExpression() {
        var model = CalculatorModel()
        enter("2", into: &model); model.onSelectOperator(.Plus); enter("3", into: &model); model.onCalculate()
        model.onPaste("not a number")
        XCTAssertEqual(model.completedExpression, "2+3")
        XCTAssertEqual(model.primaryDisplay, "5")
    }
    func testClearOperandLeavesPendingOperatorAndAcceptsReplacement() {
        for scientific in [false, true] {
            var model = CalculatorModel(); model.isScientificMode = scientific
            enter("595", into: &model); model.onSelectOperator(.Plus); enter("65", into: &model)
            model.onClearEntry(); XCTAssertEqual(model.expression, "595+")
            model.onCalculate(); XCTAssertEqual(model.expression, "595+"); XCTAssertNil(model.completedExpression)
            enter("7", into: &model); model.onCalculate(); XCTAssertEqual(model.displayedValue, "602")
            model.onAC(); enter("595", into: &model); model.onSelectOperator(.Plus); enter("65", into: &model)
            model.onClearEntry(); model.onTypeNumber(0); model.onCalculate(); XCTAssertEqual(model.displayedValue, "595")
        }
    }
    func testClearInsideParenthesisDoesNotInventZero() {
        var model = CalculatorModel(); model.isScientificMode = true
        enter("595", into: &model); model.onSelectOperator(.Plus); model.onOpenParenthesis()
        enter("65", into: &model); model.onClearEntry()
        model.onCloseParenthesis(); model.onCalculate()
        model.onMemoryAdd()
        XCTAssertEqual(model.expression, "595+("); XCTAssertNil(model.completedExpression)
        enter("7", into: &model); model.onCloseParenthesis(); model.onCalculate()
        XCTAssertEqual(model.displayedValue, "602")
    }
    func testDecimalAndTrailingZeros() {
        var model = CalculatorModel()
        enter("0.1", into: &model); model.onSelectOperator(.Plus); enter("0.2", into: &model); model.onCalculate()
        XCTAssertEqual(model.displayedValue, "0.3")
        model.onAC(); enter("1.00", into: &model)
        XCTAssertEqual(model.displayedValue, "1.00")
        model.onTypeDot(); XCTAssertEqual(model.displayedValue, "1.00")
    }
    func testPercentBehavior() {
        var model = CalculatorModel()
        enter("200", into: &model); model.onSelectOperator(.Plus); enter("10", into: &model); model.onPercentage(); model.onCalculate()
        XCTAssertEqual(model.displayedValue, "220")
        model.onAC(); enter("200", into: &model); model.onSelectOperator(.Multiply); enter("10", into: &model); model.onPercentage(); model.onCalculate()
        XCTAssertEqual(model.displayedValue, "20")
    }
    func testBackspaceAndClear() {
        var model = CalculatorModel()
        enter("123", into: &model); model.onDelete(); XCTAssertEqual(model.displayedValue, "12")
        model.onDelete(); model.onDelete(); model.onDelete(); XCTAssertEqual(model.displayedValue, "0")
        enter("8", into: &model); model.onSelectOperator(.Plus); model.onAC(); enter("2", into: &model); model.onCalculate()
        XCTAssertEqual(model.displayedValue, "2")
        XCTAssertNil(model.selectedOperator)
    }
    func testErrorRecovery() {
        var model = CalculatorModel()
        enter("8", into: &model); model.onSelectOperator(.Divide); enter("0", into: &model); model.onCalculate()
        XCTAssertEqual(model.displayedValue, "Error")
        enter("4", into: &model); XCTAssertEqual(model.displayedValue, "4")
        model.onSelectOperator(.Plus); enter("2", into: &model); model.onCalculate()
        XCTAssertEqual(model.displayedValue, "6")
    }
    func testPasteRetainsLeadingZerosAndRejectsInvalidInput() {
        var model = CalculatorModel()
        model.onPaste("0.005"); XCTAssertEqual(model.displayedValue, "0.005")
        model.onPaste("1000"); XCTAssertEqual(model.displayedValue, "1,000")
        model.onPaste("−1,234.50"); XCTAssertEqual(model.displayedValue, "−1,234.5")
        for invalid in ["nan", "infinity", "12abc", "1.2.3", ""] {
            model.onPaste(invalid); XCTAssertEqual(model.displayedValue, "−1,234.5")
        }
    }
    func testAllTwentyKeysAndOrdering() {
        XCTAssertEqual(ControlPanel.rows.count, 5)
        XCTAssertTrue(ControlPanel.rows.allSatisfy { $0.count == 4 })
        XCTAssertEqual(Set(ControlPanel.rows.flatMap { $0 }).count, 20)
        XCTAssertEqual(ControlPanel.rows.map { $0[3] }, [.Divide, .Multiply, .Minus, .Plus, .Calculate])
    }
    func testDuoMaximizesKeysWithinDisplayAndSafeMargins() {
        let size = CGSize(width: 466, height: 682)
        let layout = CalculatorLayout(availableSize: size)
        XCTAssertGreaterThan(layout.buttonSize, 236.0 / 3)
        XCTAssertEqual(layout.buttonSize, min((size.width - 32 - 3 * layout.gap) / 4,
                         (size.height - 52 - CalculatorLayout.bottomPadding - 5.5 * layout.gap) / 6.25), accuracy: 0.01)
        XCTAssertEqual(CalculatorLayout.bottomPadding, 4)
        XCTAssertLessThanOrEqual(layout.contentHeight + 52 + CalculatorLayout.bottomPadding, size.height + 0.01)
    }
    func testHomeIndicatorGutterReclaimsOnlyExcessNotCameraInsets() {
        XCTAssertEqual(CalculatorLayout.bottomExtension(for: 34), 18)
        XCTAssertEqual(CalculatorLayout.bottomExtension(for: 0), 0)
        XCTAssertEqual(CalculatorLayout.bottomExtension(for: 82), 0)
        let old = CalculatorLayout(availableSize: CGSize(width: 466, height: 562))
        let expanded = CalculatorLayout(availableSize: CGSize(width: 466, height: 580))
        XCTAssertGreaterThan(expanded.buttonSize, old.buttonSize)
    }
    func testResizingKeepsFiveRowsOnscreen() {
        for size in [CGSize(width: 393, height: 759), CGSize(width: 466, height: 620), CGSize(width: 678, height: 400), CGSize(width: 768, height: 1000)] {
            let layout = CalculatorLayout(availableSize: size)
            XCTAssertLessThanOrEqual(layout.width, size.width)
            XCTAssertLessThanOrEqual(layout.contentHeight + CalculatorLayout.bottomPadding, size.height + 0.001)
        }
    }
}

final class ScientificCalculatorTests: XCTestCase {
    private func result(_ input: String, _ function: ScientificFunction, degrees: Bool = true) -> CalculatorModel {
        var model = CalculatorModel()
        model.usesDegrees = degrees
        model.onPaste(input)
        model.onScientific(function)
        return model
    }
    func testScientificFunctions() {
        let examples: [(String, ScientificFunction, Double)] = [
            ("3", .square, 9), ("3", .cube, 27), ("81", .squareRoot, 9),
            ("-27", .cubeRoot, -3), ("4", .reciprocal, 0.25),
            ("30", .sin, 0.5), ("60", .cos, 0.5), ("45", .tan, 1),
            ("0.5", .asin, 30), ("0.5", .acos, 60), ("1", .atan, 45),
            ("1", .ln, 0), ("1000", .log10, 3), ("1", .exp, exp(1)),
            ("3", .pow10, 1000), ("5", .factorial, 120), ("0", .factorial, 1),
            ("0", .pi, .pi), ("0", .e, exp(1))
        ]
        for (input, function, expected) in examples {
            let model = result(input, function)
            XCTAssertFalse(model.isError, function.rawValue)
            XCTAssertEqual(model.computedValue, expected, accuracy: 1e-11, function.rawValue)
        }
    }
    func testRadiansAndModeSurvivesClear() {
        var model = result(String(Double.pi / 2), .sin, degrees: false)
        XCTAssertEqual(model.computedValue, 1, accuracy: 1e-12)
        model.onAC()
        XCTAssertFalse(model.usesDegrees)
        XCTAssertEqual(result("1", .atan, degrees: false).computedValue, .pi / 4, accuracy: 1e-12)
    }
    func testScientificDomainAndRangeErrors() {
        for (input, function): (String, ScientificFunction) in [
            ("-1", .squareRoot), ("0", .reciprocal), ("0", .ln), ("-1", .log10),
            ("2", .asin), ("-2", .acos), ("90", .tan), ("-1", .factorial),
            ("171", .factorial), ("1000", .exp), ("-1000", .exp)
        ] {
            var model = result(input, function)
            XCTAssertTrue(model.isError, "\(function): \(input)")
            model.onTypeNumber(7)
            XCTAssertEqual(model.displayedValue, "7")
        }
    }
    func testPowerAndRepeatEquals() {
        var model = CalculatorModel()
        model.onPaste("2"); model.onSelectOperator(.Power); model.onPaste("3"); model.onCalculate()
        XCTAssertEqual(model.computedValue, 8)
        model.onCalculate()
        XCTAssertEqual(model.computedValue, 512)
        model.onAC(); model.onPaste("-2"); model.onSelectOperator(.Power); model.onPaste("0.5"); model.onCalculate()
        XCTAssertTrue(model.isError)
    }
    func testScientificOperandAndFreshEntry() {
        var model = CalculatorModel()
        model.onPaste("10"); model.onSelectOperator(.Plus); model.onPaste("9"); model.onScientific(.squareRoot); model.onCalculate()
        XCTAssertEqual(model.computedValue, 13)
        model.onScientific(.square)
        XCTAssertEqual(model.computedValue, 169)
        model.onCalculate() // Unary operation cancels stale repeat-equals state.
        XCTAssertEqual(model.computedValue, 169)
        model.onTypeNumber(4)
        XCTAssertEqual(model.computedValue, 4)
        model.onSelectOperator(.Multiply); model.onScientific(.pi); model.onCalculate()
        XCTAssertEqual(model.computedValue, 4 * .pi, accuracy: 1e-12)
    }
    func testScientificDisplayAndRandomBounds() {
        let large = result("80", .factorial)
        XCTAssertFalse(large.isError)
        XCTAssertLessThan(large.displayedValue.count, 20)
        XCTAssertTrue(large.displayedValue.contains("e"))
        for _ in 0..<100 {
            let random = result("0", .random).computedValue
            XCTAssertGreaterThanOrEqual(random, 0)
            XCTAssertLessThan(random, 1)
        }
    }
}

final class ScientificLayoutTests: XCTestCase {
    func testAutomaticModeTracksDuoAndOrientation() {
        XCTAssertFalse(CalculatorLayout.usesScientificMode(CGSize(width: 466, height: 620)))
        XCTAssertFalse(CalculatorLayout.usesScientificMode(CGSize(width: 393, height: 759)))
        XCTAssertTrue(CalculatorLayout.usesScientificMode(CGSize(width: 669, height: 900)))
        XCTAssertTrue(CalculatorLayout.usesScientificMode(CGSize(width: 620, height: 466)))
        XCTAssertTrue(CalculatorLayout.usesScientificMode(CGSize(width: 759, height: 393)))
        // Folding back restores basic mode rather than retaining a stale orientation state.
        XCTAssertFalse(CalculatorLayout.usesScientificMode(CGSize(width: 466, height: 620)))
    }
    func testScientificPanelsFitWideDisplays() {
        for size in [CGSize(width: 669, height: 900), CGSize(width: 900, height: 669),
                     CGSize(width: 620, height: 466), CGSize(width: 759, height: 393),
                     CGSize(width: 768, height: 1000)] {
            let layout = CalculatorLayout(availableSize: size, scientific: true)
            XCTAssertGreaterThan(layout.buttonSize, 0)
            XCTAssertLessThanOrEqual(layout.panelWidth + 32, size.width + 0.001)
            XCTAssertLessThanOrEqual(layout.contentHeight + 52 + CalculatorLayout.bottomPadding, size.height + 0.001)
        }
    }
}

final class ViewportBoundsTests: XCTestCase {
    func testCompleteContentFitsEveryViewport() {
        for width in [200.0, 320, 393, 402, 466, 600, 626, 669, 678, 874, 951, 1024] {
            for height in [180.0, 300, 370, 400, 466, 550, 600, 620, 644, 678, 900, 951] {
                for scientific in [false, true] {
                    let layout = CalculatorLayout(availableSize: CGSize(width: width, height: height), scientific: scientific)
                    let totalWidth = layout.panelWidth + 32
                    let totalHeight = layout.contentHeight + 52 + CalculatorLayout.bottomPadding
                    XCTAssertLessThanOrEqual(totalWidth, width + 0.001)
                    XCTAssertLessThanOrEqual(totalHeight, height + 0.001)
                    XCTAssertGreaterThan(layout.buttonSize, 0)
                }
            }
        }
    }
}

final class ExtendedScientificEngineTests: XCTestCase {
    private func scientific() -> CalculatorModel { var m = CalculatorModel(); m.isScientificMode = true; return m }
    func testPrecedenceAndRepeat() {
        var m = scientific()
        m.onPaste("2"); m.onSelectOperator(.Plus); m.onPaste("3"); m.onSelectOperator(.Multiply); m.onPaste("4")
        XCTAssertEqual(m.previewValue, "14")
        XCTAssertEqual(m.computedValue, 4)
        m.onCalculate(); XCTAssertEqual(m.computedValue, 14)
        m.onCalculate(); XCTAssertEqual(m.computedValue, 26)
    }
    func testNestedParenthesesAndImplicitMultiplication() {
        var m = scientific()
        m.onPaste("2"); m.onOpenParenthesis(); m.onPaste("3"); m.onSelectOperator(.Plus)
        m.onOpenParenthesis(); m.onPaste("4"); m.onSelectOperator(.Multiply); m.onPaste("5"); m.onCloseParenthesis(); m.onCloseParenthesis()
        XCTAssertEqual(m.expression, "2×(3+(4×5))")
        m.onCalculate(); XCTAssertEqual(m.computedValue, 46); XCTAssertEqual(m.parenthesisDepth, 0)
    }
    func testEqualsClosesParenthesesAndModePreservesExpression() {
        var m = scientific()
        m.onPaste("2"); m.onSelectOperator(.Plus); m.onOpenParenthesis(); m.onPaste("3"); m.onSelectOperator(.Multiply); m.onPaste("4")
        m.isScientificMode = false
        m.onCalculate(); XCTAssertEqual(m.computedValue, 14)
    }
    func testBinaryScientificOperations() {
        for (left, op, right, expected): (String, ButtonType, String, Double) in [
            ("27", .Root, "3", 3), ("-27", .Root, "3", -3), ("3", .ReversePower, "2", 8),
            ("81", .LogBase, "3", 4), ("2", .Power, "8", 256)
        ] {
            var m = scientific(); m.onPaste(left); m.onSelectOperator(op); m.onPaste(right); m.onCalculate()
            XCTAssertEqual(m.computedValue, expected, accuracy: 1e-12)
        }
    }
    func testExtraUnaryFunctions() {
        for (input, function, expected): (String, ScientificFunction, Double) in [
            ("8", .log2, 3), ("3", .pow2, 8), ("1", .sinh, sinh(1)), ("1", .cosh, cosh(1)),
            ("1", .tanh, tanh(1)), ("1", .asinh, asinh(1)), ("2", .acosh, acosh(2)), ("0.5", .atanh, atanh(0.5))
        ] {
            var m = scientific(); m.onPaste(input); m.onScientific(function)
            XCTAssertEqual(m.computedValue, expected, accuracy: 1e-12)
        }
    }
    func testExponentEntrySignedAndDelete() {
        var m = scientific(); m.onTypeNumber(2); m.onExponent(); m.onPlusMinus(); m.onTypeNumber(3)
        XCTAssertEqual(m.computedValue, 0.002)
        m.onDelete(); XCTAssertEqual(m.computedValue, 2)
        m.onTypeNumber(4); XCTAssertEqual(m.computedValue, 0.0002)
        m.onAC(); m.onTypeNumber(3); m.onExponent(); m.onTypeNumber(2); m.onSelectOperator(.Plus); m.onTypeNumber(1); m.onCalculate()
        XCTAssertEqual(m.computedValue, 301)
    }
    func testMemorySurvivesClearAndRecallsOperand() {
        var m = scientific(); m.onPaste("12"); m.onMemoryAdd(); m.onAC()
        XCTAssertTrue(m.hasMemory)
        m.onPaste("2"); m.onMemorySubtract(); m.onAC(); m.onPaste("3"); m.onSelectOperator(.Multiply); m.onMemoryRecall(); m.onCalculate()
        XCTAssertEqual(m.computedValue, 30)
        m.onMemoryClear(); XCTAssertFalse(m.hasMemory)
    }
    func testFullRangeFactorialAndArithmetic() {
        var m = scientific(); m.onPaste("170"); m.onScientific(.factorial)
        XCTAssertFalse(m.isError); XCTAssertEqual(m.computedValue / 7.257415615307999e306, 1, accuracy: 1e-13)
        m.onSelectOperator(.Divide); m.onPaste("1e200"); m.onCalculate()
        XCTAssertFalse(m.isError); XCTAssertEqual(m.computedValue / 7.257415615307999e106, 1, accuracy: 1e-13)
        m.onAC(); m.onPaste("171"); m.onScientific(.factorial); XCTAssertTrue(m.isError)
    }
    func testDomainsAndOverflow() {
        for (left, op, right): (String, ButtonType, String) in [("-4", .Root, "2"), ("4", .Root, "0"), ("10", .LogBase, "1"), ("-1", .LogBase, "2"), ("1e308", .Multiply, "10")] {
            var m = scientific(); m.onPaste(left); m.onSelectOperator(op); m.onPaste(right); m.onCalculate(); XCTAssertTrue(m.isError)
        }
        for (input, function): (String, ScientificFunction) in [("0", .log2), ("0", .acosh), ("1", .atanh)] {
            var m = scientific(); m.onPaste(input); m.onScientific(function); XCTAssertTrue(m.isError)
        }
    }
    func testClearOperandAndOperatorReplacement() {
        var m = scientific(); m.onPaste("8"); m.onSelectOperator(.Plus); m.onSelectOperator(.Divide); m.onPaste("9"); m.onClearEntry(); m.onTypeNumber(2); m.onCalculate()
        XCTAssertEqual(m.computedValue, 4)
    }
    func testHistoryAndPreviewAreIndependent() {
        var m = scientific(); m.onPaste("2"); m.onSelectOperator(.Plus); m.onPaste("3")
        XCTAssertEqual(m.previewValue, "5"); XCTAssertTrue(m.history.isEmpty)
        m.onCalculate(); XCTAssertEqual(m.history.first?.expression, "2+3"); XCTAssertEqual(m.history.first?.result, "5")
        let id = m.history[0].id
        m.onAC(); XCTAssertEqual(m.history.count, 1)
        m.restoreHistory(id); XCTAssertEqual(m.computedValue, 5)
        m.deleteHistory(id); XCTAssertTrue(m.history.isEmpty)
    }
}

final class ScientificEngineRegressionTests: XCTestCase {
    func testEqualsOnParenthesizedExpressionDoesNotRepeatInnerOperation() {
        var m = CalculatorModel(); m.isScientificMode = true
        m.onOpenParenthesis(); m.onPaste("2"); m.onSelectOperator(.Plus); m.onPaste("3"); m.onCalculate()
        XCTAssertEqual(m.computedValue, 5)
    }
    func testReplacingOperatorReevaluatesPrecedence() {
        var m = CalculatorModel(); m.isScientificMode = true
        m.onPaste("10"); m.onSelectOperator(.Minus); m.onPaste("3"); m.onSelectOperator(.Multiply); m.onSelectOperator(.Plus); m.onPaste("4"); m.onCalculate()
        XCTAssertEqual(m.computedValue, 11)
    }
    func testModeSwitchMigratesPendingBasicOperation() {
        var m = CalculatorModel()
        m.onPaste("2"); m.onSelectOperator(.Plus); m.isScientificMode = true
        m.onPaste("3"); m.onSelectOperator(.Multiply); m.onPaste("4"); m.onCalculate()
        XCTAssertEqual(m.computedValue, 14)
    }
    func testHistoryCodableAndClearState() throws {
        var m = CalculatorModel(); m.onPaste("4"); XCTAssertTrue(m.shouldClearEntry)
        m.onClearEntry(); XCTAssertFalse(m.shouldClearEntry)
        m.onPaste("5"); m.onCalculate()
        let data = try JSONEncoder().encode(m.history)
        let entries = try JSONDecoder().decode([CalculatorModel.HistoryEntry].self, from: data)
        m.clearHistory(); m.loadHistory(entries)
        XCTAssertEqual(m.history.first?.result, "5")
    }
}

final class ScientificPrefixFunctionTests: XCTestCase {
    func testFreshPrefixFunctionAndPostfixBothWork() {
        var m = CalculatorModel(); m.isScientificMode = true
        m.onScientific(.sin); m.onTypeNumber(3); m.onTypeNumber(0)
        XCTAssertEqual(m.previewValue, "0.5")
        m.onCalculate(); XCTAssertEqual(m.computedValue, 0.5, accuracy: 1e-12)
        m.onAC(); m.onPaste("30"); m.onScientific(.sin)
        XCTAssertEqual(m.computedValue, 0.5, accuracy: 1e-12)
    }
    func testPrefixFunctionInsidePendingDivision() {
        var m = CalculatorModel(); m.isScientificMode = true
        m.onPaste("1"); m.onSelectOperator(.Divide); m.onScientific(.sin)
        m.onPaste("15"); m.onSelectOperator(.Plus); m.onPaste("15"); m.onCloseParenthesis()
        XCTAssertEqual(m.expression, "1÷sin(15+15)")
        m.onCalculate(); XCTAssertEqual(m.computedValue, 2, accuracy: 1e-12)
    }
    func testNestedPrefixFunctionsAndExplicitGroups() {
        var m = CalculatorModel(); m.isScientificMode = true
        m.onScientific(.sin); m.onScientific(.asin); m.onOpenParenthesis()
        m.onPaste("0.25"); m.onSelectOperator(.Plus); m.onPaste("0.25"); m.onCalculate()
        XCTAssertEqual(m.computedValue, 0.5, accuracy: 1e-12)
    }
}

final class ScientificFunctionFinalRegressionTests: XCTestCase {
    func testUnaryAfterEqualsUsesCompletedResult() {
        var m = CalculatorModel(); m.isScientificMode = true
        m.onPaste("15"); m.onSelectOperator(.Plus); m.onPaste("15"); m.onCalculate(); m.onScientific(.sin)
        XCTAssertEqual(m.computedValue, 0.5, accuracy: 1e-12)
        XCTAssertEqual(m.parenthesisDepth, 0)
    }
    func testRealFactorialAndMathematicalLabels() {
        var m = CalculatorModel(); m.isScientificMode = true
        m.onPaste("1.5"); m.onScientific(.factorial)
        XCTAssertFalse(m.isError)
        XCTAssertEqual(m.computedValue, 1.329340388179137, accuracy: 1e-12)
        m.onAC(); m.onScientific(.squareRoot); m.onPaste("9")
        XCTAssertEqual(m.expression, "√(9")
        m.onCalculate(); XCTAssertEqual(m.computedValue, 3)
    }
}

final class ScientificMemoryPreviewTests: XCTestCase {
    func testMemoryStoresVisibleLiveResult() {
        var model = CalculatorModel(); model.isScientificMode = true
        model.onTypeNumber(2); model.onSelectOperator(.Plus); model.onTypeNumber(3)
        XCTAssertEqual(model.previewValue, "5")
        model.onMemoryAdd(); model.onAC(); model.onMemoryRecall()
        XCTAssertEqual(model.computedValue, 5)
    }
}

final class EditableExpressionEvaluatorTests: XCTestCase {
    private func value(_ text: String, degrees: Bool = true) throws -> Double {
        try ExpressionEvaluator.evaluate(text, usesDegrees: degrees)
    }
    func testPrecedenceAssociativityAndSigns() throws {
        for (text, expected) in [("2+3×4", 14.0), ("2^3^2", 512), ("-2^2", -4),
                                 ("(-2)^2", 4), ("2^-2", 0.25), ("2^-2^2", 0.0625),
                                 ("10-3-2", 5), ("24/4/2", 3), ("3!^2", 36)] {
            XCTAssertEqual(try value(text), expected, accuracy: 1e-12, text)
        }
    }
    func testNestedEditedAndPastedExpressions() throws {
        XCTAssertEqual(try value("2(3+(4×5))"), 46)
        XCTAssertEqual(try value("2(30+(4×5))"), 100)
        XCTAssertEqual(try value("\n 2 × ( 3 + 4 ) \t"), 14)
        XCTAssertEqual(try value("(2+3)(4+5)"), 45)
        XCTAssertEqual(try value("(2)3"), 6)
        XCTAssertEqual(try value("2π+ππ"), 2 * .pi + .pi * .pi, accuracy: 1e-12)
        XCTAssertEqual(try value("2sin(30)"), 1, accuracy: 1e-12)
    }
    func testDecimalArithmeticAndFullDoubleRange() throws {
        XCTAssertEqual(try ExpressionEvaluator.evaluateResult("0.1+0.2").formatted, "0.3")
        XCTAssertEqual(try value("(0.1+0.2)-0.3"), 0)
        XCTAssertEqual(try value("1e308/2"), 5e307)
        XCTAssertEqual(try value("5e-324"), Double.leastNonzeroMagnitude)
        let maximum = try ExpressionEvaluator.evaluateResult("1.7976931348623157e308")
        XCTAssertEqual(try value(maximum.formatted), Double.greatestFiniteMagnitude)
        XCTAssertEqual(try value("170!") / 7.257415615307999e306, 1, accuracy: 1e-13)
        XCTAssertThrowsError(try value("1e309"))
        XCTAssertThrowsError(try value("1e308*10"))
        XCTAssertThrowsError(try value("1e-400"))
        XCTAssertThrowsError(try value("1e-300*1e-300"))
    }
    func testExponentNotationAndEulerConstantAreDistinct() throws {
        XCTAssertEqual(try value("2e"), 2 * exp(1), accuracy: 1e-12)
        XCTAssertEqual(try value("2e3"), 2000)
        XCTAssertEqual(try value("2E3"), 2000)
        XCTAssertEqual(try value("2EE-3"), 0.002)
        XCTAssertEqual(try value("2e(-1)"), -2 * exp(1), accuracy: 1e-12)
        XCTAssertEqual(try value("exp(1)"), exp(1), accuracy: 1e-12)
    }
    func testLegacyExpressionLabelsAndCanonicalFunctions() throws {
        for (text, expected) in [("2xʸ3", 8.0), ("3yˣ2", 8), ("27ʸ√x3", 3),
                                 ("81logᵧ3", 4), ("(3)²+(2)³", 17), ("√(9)+∛(-8)", 1),
                                 ("sin⁻¹(0.5)", 30), ("log₁₀(100)+log₂(8)", 5),
                                 ("root(-27,3)", -3), ("reversePower(3,2)", 8),
                                 ("logBase(81,3)", 4), ("1/(4)", 0.25), ("reciprocal(4)", 0.25),
                                 ("pow10(2)+pow2(3)", 108)] {
            XCTAssertEqual(try value(text), expected, accuracy: 1e-10, text)
        }
    }
    func testTrigonometricAndHyperbolicModes() throws {
        XCTAssertEqual(try value("sin(30)+cos(60)"), 1, accuracy: 1e-12)
        XCTAssertEqual(try value("sin(pi/2)", degrees: false), 1, accuracy: 1e-12)
        XCTAssertEqual(try value("atan(1)", degrees: false), .pi / 4, accuracy: 1e-12)
        XCTAssertEqual(try value("asin(0.5)"), 30, accuracy: 1e-12)
        for text in ["sinh(asinh(0.5))", "cosh(acosh(2))/4", "tanh(atanh(0.5))", "sinh(sinh⁻¹(0.5))"] {
            XCTAssertEqual(try value(text), 0.5, accuracy: 1e-12)
        }
    }
    func testFactorialGammaAndPercent() throws {
        XCTAssertEqual(try value("0!"), 1)
        XCTAssertEqual(try value("1.5!"), 1.329340388179137, accuracy: 1e-12)
        XCTAssertEqual(try value("200*10%"), 20)
        XCTAssertEqual(try value("200+10%"), 220)
        XCTAssertEqual(try value("200-10%"), 180)
        XCTAssertEqual(try value("200/10%"), 2000)
        XCTAssertEqual(try value("10%"), 0.1)
        XCTAssertEqual(try value("200+(10%)"), 220)
        XCTAssertEqual(try value("200+(-10%)"), 180)
        XCTAssertEqual(try value("200+10%+10%"), 242)
        XCTAssertEqual(try value("(100+100)+10%"), 220)
        XCTAssertEqual(try value("200+(5+5)%"), 220)
        XCTAssertEqual(try value("200+10%*2"), 200.2)
        XCTAssertThrowsError(try value("(-1)!"))
        XCTAssertThrowsError(try value("171!"))
    }
    func testIncompleteInputIsDistinguishedFromInvalid() {
        for text in ["", ".", "2+", "sin(", "(2+3", "2EE", "2E-", "root(27,"] {
            XCTAssertThrowsError(try value(text)) { error in
                XCTAssertTrue((error as? ExpressionEvaluator.EvaluationError)?.isIncomplete == true, text)
            }
        }
        for text in ["1.2.3", "1 2", "2+)", "sin()", "2)", "root(1)", "sqrt(1,2)"] {
            XCTAssertThrowsError(try value(text)) { error in
                XCTAssertFalse((error as? ExpressionEvaluator.EvaluationError)?.isIncomplete ?? true, text)
            }
        }
    }
    func testDomainsAndUntrustedTextAreRejected() {
        for text in ["sqrt(-1)", "ln(0)", "logBase(10,1)", "root(-4,2)", "root(4,0)",
                     "asin(2)", "acosh(0)", "atanh(1)", "tan(90)", "1/0", "(-2)^0.5",
                     "NaN", "Infinity", "system(1)", "__import__('os')", "2;exit()", "a=3", "1/**/2"] {
            XCTAssertThrowsError(try value(text), text)
        }
    }
    func testParserComplexityIsBoundedAndCallsAreIndependent() throws {
        XCTAssertThrowsError(try value(String(repeating: "(", count: 200) + "1" + String(repeating: ")", count: 200)))
        XCTAssertThrowsError(try value(String(repeating: "1+", count: 3000) + "1"))
        _ = try? value("sin(")
        XCTAssertEqual(try value("2+3"), 5)
        XCTAssertEqual(try value("sin(30)"), 0.5, accuracy: 1e-12)
    }
}

final class ModelExpressionRoundTripTests: XCTestCase {
    func testEveryScientificFunctionOutputCanBeEditedAndReevaluated() throws {
        for function in ScientificFunction.allCases {
            var model = CalculatorModel()
            model.isScientificMode = true
            model.onPaste(function == .acosh ? "2" : "0.5")
            model.onScientific(function)
            XCTAssertFalse(model.isError, function.rawValue)
            let reparsed = try ExpressionEvaluator.evaluate(model.expression, usesDegrees: model.usesDegrees)
            XCTAssertEqual(reparsed, model.computedValue, accuracy: max(1, abs(model.computedValue)) * 1e-12, function.rawValue)
        }
    }
    func testEveryBinaryOperatorOutputCanBeEditedAndReevaluated() throws {
        for operation in ButtonType.allCases where operation.isOperation {
            var model = CalculatorModel()
            model.isScientificMode = true
            model.onPaste("8"); model.onSelectOperator(operation); model.onPaste("2")
            let source = model.expression
            let reparsed = try ExpressionEvaluator.evaluate(source)
            model.onCalculate()
            XCTAssertFalse(model.isError, operation.rawValue)
            XCTAssertEqual(reparsed, model.computedValue, accuracy: 1e-10, source)
        }
    }
    func testPercentageKeyExpressionRoundTrips() throws {
        for operation in [ButtonType.Plus, .Minus, .Multiply, .Divide] {
            var model = CalculatorModel()
            model.isScientificMode = true
            model.onPaste("200"); model.onSelectOperator(operation); model.onPaste("10"); model.onPercentage()
            let source = model.expression
            let reparsed = try ExpressionEvaluator.evaluate(source)
            model.onCalculate()
            XCTAssertEqual(reparsed, model.computedValue, accuracy: 1e-10, source)
        }
    }
}

final class FinalEditorBoundaryTests: XCTestCase {
    func testEditedMaximumFiniteResultRemainsValid() {
        var model = CalculatorModel()
        model.commitEditedExpression("1.7976931348623157e308", result: Double.greatestFiniteMagnitude)
        XCTAssertFalse(model.isError)
        XCTAssertEqual(model.computedValue, Double.greatestFiniteMagnitude)
        XCTAssertTrue(Double(model.displayedValue)?.isFinite == true)
        XCTAssertEqual(model.history.first?.result, model.entry)
    }
    func testConversionLayoutFitsViewports() {
        for width in [200.0, 320, 393, 466, 600, 669, 678, 874, 951] {
            for height in [180.0, 300, 370, 400, 466, 620, 678, 900] {
                let layout = CalculatorLayout(availableSize: CGSize(width: width, height: height), converting: true)
                XCTAssertLessThanOrEqual(layout.panelWidth + 32, width + 0.001)
                XCTAssertLessThanOrEqual(layout.contentHeight + 52 + CalculatorLayout.bottomPadding, height + 0.001)
                XCTAssertGreaterThan(layout.buttonSize, 0)
            }
        }
    }
}

final class ExpressionDisplayTests: XCTestCase {
    func testExpressionIsPrimaryUntilEqualsThenMovesToSubtitle() {
        var model = CalculatorModel()
        model.onTypeNumber(7); model.onSelectOperator(.Plus); model.onTypeNumber(5)
        XCTAssertEqual(model.primaryDisplay, "7+5")
        XCTAssertEqual(model.livePreview, "12")
        XCTAssertNil(model.completedExpression)
        model.onCalculate()
        XCTAssertEqual(model.primaryDisplay, "12")
        XCTAssertEqual(model.completedExpression, "7+5")
        XCTAssertNil(model.livePreview)
        model.onSelectOperator(.Multiply); model.onTypeNumber(2)
        XCTAssertNil(model.completedExpression)
        XCTAssertEqual(model.primaryDisplay, "12×2")
        model.onCalculate(); XCTAssertEqual(model.primaryDisplay, "24")
        model.onAC(); XCTAssertNil(model.completedExpression)
    }
    func testEditedExpressionCommitsAndNewInputRestoresEntryDisplay() {
        var model = CalculatorModel()
        model.commitEditedExpression("2+3×4", result: 14)
        XCTAssertEqual(model.completedExpression, "2+3×4")
        XCTAssertEqual(model.primaryDisplay, "14")
        model.onTypeNumber(8)
        XCTAssertNil(model.completedExpression)
        XCTAssertEqual(model.primaryDisplay, "8")
    }
}
