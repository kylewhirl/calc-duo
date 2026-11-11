// Adapted from bofeiw/ios-calculator-clone-for-ipados (CC0-1.0).
import SwiftUI

struct CalculatorView: View {
    @State private var calculator = CalculatorModel()
    @AppStorage("leftHandedLayout") private var leftHanded = false
    @AppStorage("calculationHistory") private var storedHistory = Data()
    @State private var showingHistory = false
    @State private var historyUsesSidebar = false
    @State private var converting = false
    @State private var second = false
    @State private var editingExpression = false
    @State private var expressionText = ""
    @State private var expressionSelection = NSRange(location: 0, length: 0)
    @State private var editorError: String? = nil
    @State private var modeOverride: Bool? = nil
    @State private var deviceIsLandscape = UIDevice.current.orientation.isLandscape

    private func onDisplayAreaClick(_ event: DisplayAreaEvent) {
        switch event {
        case .CopyToClipBoard: UIPasteboard.general.string = calculator.displayedValue
        case .Paste: if let value = UIPasteboard.general.string { calculator.onPaste(value) }
        case .Delete: calculator.onDelete()
        }
    }
    private func onControlPanelClick(_ key: ButtonType) {
        if editingExpression { onEditorKey(key); return }
        if let digit = key.digit { calculator.onTypeNumber(digit); return }
        if key.isOperation { calculator.onSelectOperator(key); return }
        switch key {
        case .Dot: calculator.onTypeDot()
        case .Calculate: calculator.onCalculate()
        case .AC: calculator.shouldClearEntry ? calculator.onClearEntry() : calculator.onAC()
        case .PlusMinus: calculator.onPlusMinus()
        case .Percentage: calculator.onPercentage()
        case .Backspace: calculator.onDelete()
        default: break
        }
    }
    var body: some View {
        GeometryReader { geometry in
            let automatic = deviceIsLandscape || CalculatorLayout.usesScientificMode(geometry.size)
            let scientific = !converting && (modeOverride ?? automatic)
            let wideHistory = geometry.size.width > geometry.size.height
            let sidebarWidth = showingHistory && wideHistory ? min(280, geometry.size.width * 0.34) : 0
            let available = CGSize(width: geometry.size.width - sidebarWidth, height: geometry.size.height)
            let layout = CalculatorLayout(availableSize: available, scientific: scientific, converting: converting)
            HStack(spacing: 0) {
                if sidebarWidth > 0 {
                    HistoryPanel(history: calculator.history, onRecall: recallHistory, onDelete: { calculator.deleteHistory($0) },
                                 onClear: { calculator.clearHistory() }, onClose: { showingHistory = false })
                        .frame(width: sidebarWidth)
                }
            VStack(spacing: 0) {
                    HStack {
                        if sidebarWidth == 0 {
                            Button { historyUsesSidebar = wideHistory; showingHistory = true } label: {
                                Image(systemName: wideHistory ? "sidebar.left" : "clock")
                                    .font(.system(size: 23)).frame(width: 48, height: 48)
                                    .background(Color(hex: 0x242424), in: Circle())
                                    .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.65))
                            }
                            .accessibilityLabel("History").accessibilityIdentifier("calculator_history")
                        }
                        Spacer()
                        Menu {
                            Picker("", selection: Binding(get: { scientific }, set: { modeOverride = $0; converting = false })) {
                                Label("Basic", systemImage: "plus.forwardslash.minus").tag(false)
                                Label("Scientific", systemImage: "function").tag(true)
                            }.pickerStyle(.inline)
                            Toggle(isOn: $leftHanded) { Label("Left-handed", systemImage: "hand.raised") }
                                .accessibilityIdentifier("left_handed_toggle")
                            Divider()
                            Toggle(isOn: $converting) { Label("Convert", systemImage: "arrow.left.arrow.right") }
                                .accessibilityIdentifier("convert_toggle")
                        } label: {
                            CalculatorModeGlyph().frame(width: 18, height: 26)
                                .frame(width: 48, height: 48)
                                .background(Color(hex: 0x242424), in: Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.65))
                        }
                        .accessibilityLabel("Calculator mode and settings").accessibilityIdentifier("calculator_settings")
                    }
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)
                Spacer(minLength: 0)
                VStack(spacing: layout.gap * 1.5) {
                    if converting {
                        ConversionPanel(input: calculator.entry, onUseValue: { calculator.onPaste($0) })
                            .frame(height: layout.displayHeight)
                    } else if scientific || editingExpression {
                        scientificDisplay(layout)
                    } else {
                        DisplayArea(eventCallback: onDisplayAreaClick, currentDisplay: calculator.primaryDisplay,
                                    buttonSize: layout.buttonSize, previewValue: calculator.livePreview, expression: calculator.completedExpression, displayHeight: layout.displayHeight, editingAction: { beginExpressionEditing(calculator.editableExpression) }, scientificAction: { modeOverride = true },
                                    historyAction: { historyUsesSidebar = wideHistory; showingHistory = true })
                    }
                    if scientific && layout.stacked {
                        VStack(spacing: layout.gap) {
                            scientificPanel(layout)
                            ControlPanel(layout: layout, selectedOperator: calculator.selectedOperator, clearLabel: calculator.shouldClearEntry ? "C" : "AC", clickCallback: onControlPanelClick)
                        }
                    } else {
                        HStack(spacing: layout.gap) {
                            if scientific { scientificPanel(layout) }
                            ControlPanel(layout: layout, selectedOperator: calculator.selectedOperator, clearLabel: calculator.shouldClearEntry ? "C" : "AC", clickCallback: onControlPanelClick)
                        }
                    }
                }
                .frame(width: layout.panelWidth)
                .frame(maxWidth: .infinity, alignment: scientific ? .center : leftHanded ? .leading : .trailing)
            }
            .padding(.horizontal, CalculatorLayout.edgePadding)
            .padding(.bottom, CalculatorLayout.bottomPadding)
            .frame(width: available.width, height: geometry.size.height, alignment: .bottom)
            }
            .onChange(of: scientific, initial: true) { _, value in calculator.isScientificMode = value }
            .onChange(of: automatic) { _, _ in modeOverride = nil }
            .onChange(of: wideHistory, initial: true) { _, value in historyUsesSidebar = value }
        }
        .background(Color.black.ignoresSafeArea()).preferredColorScheme(.dark).statusBarHidden(true)
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            deviceIsLandscape = UIDevice.current.orientation.isLandscape
            if let entries = try? JSONDecoder().decode([CalculatorModel.HistoryEntry].self, from: storedHistory) { calculator.loadHistory(entries) }
        }
        .onChange(of: calculator.history.map(\.id)) { _, _ in
            if let data = try? JSONEncoder().encode(calculator.history) { storedHistory = data }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let orientation = UIDevice.current.orientation
            if orientation.isLandscape || orientation.isPortrait { deviceIsLandscape = orientation.isLandscape }
        }
        .sheet(isPresented: Binding(get: { showingHistory && !historyUsesSidebar }, set: { if !$0 { showingHistory = false } })) { historyView }
        .onChange(of: expressionText) { _, _ in editorError = nil }
        .onChange(of: converting) { _, value in if value { editingExpression = false } }
    }

    private func scientificDisplay(_ layout: CalculatorLayout) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            if editingExpression {
                ExpressionField(text: $expressionText, selection: $expressionSelection, editing: $editingExpression,
                                fontSize: layout.buttonHeight * 0.78, onBeginEditing: {})
                    .frame(height: min(layout.buttonHeight, layout.displayHeight * 0.6))
                Text(editorError ?? editingPreview)
                    .font(.system(size: min(layout.buttonHeight * 0.36, layout.displayHeight * 0.25), weight: .light))
                    .foregroundColor(editorError == nil ? .secondary : .orange)
                    .lineLimit(1).minimumScaleFactor(0.2).accessibilityIdentifier("editing_preview")
            } else {
                DisplayArea(eventCallback: onDisplayAreaClick, currentDisplay: calculator.primaryDisplay,
                            buttonSize: layout.buttonHeight, previewValue: calculator.livePreview,
                            expression: calculator.completedExpression, displayHeight: layout.displayHeight,
                            editingAction: { beginExpressionEditing(calculator.editableExpression) })
            }
        }
        .frame(height: layout.displayHeight, alignment: .bottomTrailing)
        .overlay(alignment: .bottomLeading) {
            if layout.scientific && !layout.stacked {
                Text(calculator.usesDegrees ? "Deg" : "Rad").font(.system(size: 14)).foregroundStyle(.white)
                    .accessibilityLabel(calculator.usesDegrees ? "Degrees" : "Radians")
            }
        }
    }
    private func recallHistory(_ item: CalculatorModel.HistoryEntry) {
        calculator.restoreHistory(item.id)
        beginExpressionEditing(item.expression)
        showingHistory = false
    }
    private var historyView: some View {
        HistoryPanel(history: calculator.history, onRecall: recallHistory, onDelete: { calculator.deleteHistory($0) },
                     onClear: { calculator.clearHistory() }, onClose: { showingHistory = false })
    }

    private var editingPreview: String {
        do { return "= " + (try ExpressionEvaluator.evaluateResult(expressionText, usesDegrees: calculator.usesDegrees)).formatted }
        catch let error as ExpressionEvaluator.EvaluationError { return error.isIncomplete ? "…" : "Error" }
        catch { return "Error" }
    }
    private func beginExpressionEditing(_ text: String) {
        expressionText = text
        expressionSelection = NSRange(location: text.utf16.count, length: 0)
        editorError = nil
        editingExpression = true
    }
    private func insertExpression(_ text: String) {
        let source = expressionText as NSString
        let location = min(expressionSelection.location, source.length)
        let length = min(expressionSelection.length, source.length - location)
        guard source.length - length + text.utf16.count <= 2048 else { return }
        expressionText = source.replacingCharacters(in: NSRange(location: location, length: length), with: text)
        expressionSelection = NSRange(location: location + text.utf16.count, length: 0)
        editorError = nil
    }
    private func wrapSelection(_ prefix: String, suffix: String = ")") {
        let source = expressionText as NSString
        let location = min(expressionSelection.location, source.length)
        let length = min(expressionSelection.length, source.length - location)
        if length > 0 {
            let selected = source.substring(with: NSRange(location: location, length: length))
            insertExpression(prefix + selected + suffix)
        } else { insertExpression(prefix) }
    }
    private func onEditorKey(_ key: ButtonType) {
        if let digit = key.digit { insertExpression(String(digit)); return }
        switch key {
        case .Plus: insertExpression("+")
        case .Minus: insertExpression("−")
        case .Multiply: insertExpression("×")
        case .Divide: insertExpression("÷")
        case .Power: insertExpression("^")
        case .Dot: insertExpression(".")
        case .Percentage: insertExpression("%")
        case .PlusMinus: wrapSelection("−(")
        case .AC:
            expressionText = ""; expressionSelection = NSRange(location: 0, length: 0); editorError = nil
            calculator.onAC()
        case .Backspace:
            if !expressionText.isEmpty && expressionSelection.length == 0 && expressionSelection.location > 0 {
                let source = expressionText as NSString
                expressionSelection = source.rangeOfComposedCharacterSequence(at: min(expressionSelection.location, source.length) - 1)
            }
            insertExpression("")
        case .Calculate:
            do {
                let result = try ExpressionEvaluator.evaluateResult(expressionText, usesDegrees: calculator.usesDegrees)
                calculator.commitEditedExpression(expressionText, result: result.value)
                editingExpression = false; editorError = nil
            } catch { editorError = "Check expression" }
        default: break
        }
    }
    private func onEditorScientific(_ row: Int, _ col: Int) {
        switch (row, col) {
        case (0,0): insertExpression("(")
        case (0,1): insertExpression(")")
        case (0,2): calculator.onMemoryClear()
        case (0,3), (0,4):
            if let result = try? ExpressionEvaluator.evaluateResult(expressionText, usesDegrees: calculator.usesDegrees) {
                calculator.onPaste(String(result.value))
                if col == 3 { calculator.onMemoryAdd() } else { calculator.onMemorySubtract() }
            }
        case (0,5): calculator.onMemoryRecall(); insertExpression(calculator.entry)
        case (1,0): second.toggle()
        case (1,1): insertExpression("²")
        case (1,2): insertExpression("³")
        case (1,3): insertExpression("^")
        case (1,4): if second { insertExpression("yˣ") } else { wrapSelection("exp(") }
        case (1,5): wrapSelection(second ? "pow2(" : "pow10(")
        case (2,0): wrapSelection("reciprocal(")
        case (2,1): wrapSelection("sqrt(")
        case (2,2): wrapSelection("cbrt(")
        case (2,3): insertExpression("ʸ√x")
        case (2,4): if second { insertExpression("logᵧ") } else { wrapSelection("ln(") }
        case (2,5): wrapSelection(second ? "log2(" : "log10(")
        case (3,0): insertExpression("!")
        case (3,1): wrapSelection(second ? "asin(" : "sin(")
        case (3,2): wrapSelection(second ? "acos(" : "cos(")
        case (3,3): wrapSelection(second ? "atan(" : "tan(")
        case (3,4): insertExpression("e")
        case (3,5): insertExpression("E")
        case (4,0): insertExpression(String(Double.random(in: 0..<1)))
        case (4,1): wrapSelection(second ? "asinh(" : "sinh(")
        case (4,2): wrapSelection(second ? "acosh(" : "cosh(")
        case (4,3): wrapSelection(second ? "atanh(" : "tanh(")
        case (4,4): insertExpression("π")
        case (4,5): calculator.usesDegrees.toggle()
        default: break
        }
    }

    private var scienceLabels: [[String]] {
        [
            ["(", ")", "mc", "m+", "m−", "mr"],
            ["2ⁿᵈ", "x²", "x³", "xʸ", second ? "yˣ" : "eˣ", second ? "2ˣ" : "10ˣ"],
            ["1/x", "²√x", "³√x", "ʸ√x", second ? "logᵧ" : "ln", second ? "log₂" : "log₁₀"],
            ["x!", second ? "sin⁻¹" : "sin", second ? "cos⁻¹" : "cos", second ? "tan⁻¹" : "tan", "e", "EE"],
            ["Rand", second ? "sinh⁻¹" : "sinh", second ? "cosh⁻¹" : "cosh", second ? "tanh⁻¹" : "tanh", "π", calculator.usesDegrees ? "Rad" : "Deg"]
        ]
    }
    private let scienceIDs = [
        ["open_parenthesis", "close_parenthesis", "memory_clear", "memory_add", "memory_subtract", "memory_recall"],
        ["second", "square", "cube", "power", "exp", "pow10"],
        ["reciprocal", "squareRoot", "cubeRoot", "root", "ln", "log10"],
        ["factorial", "sin", "cos", "tan", "e", "exponent"],
        ["random", "sinh", "cosh", "tanh", "pi", "angle"]
    ]
    private func scientificPanel(_ layout: CalculatorLayout) -> some View {
        VStack(spacing: layout.gap) {
            ForEach(0..<5) { row in
                HStack(spacing: layout.gap) {
                    ForEach(0..<6) { column in
                        Button { scientificTap(row, column) } label: {
                            Text(scienceLabels[row][column])
                                .font(.system(size: max(10, layout.buttonHeight * 0.32)))
                                .foregroundStyle(row == 1 && column == 0 && second ? .black : .white)
                                .frame(width: layout.scientificButtonWidth, height: layout.buttonHeight)
                                .background(row == 1 && column == 0 && second ? .white : Color(hex: 0x242424), in: Capsule())
                                .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 0.65))
                        }
                        .accessibilityLabel(scienceLabels[row][column])
                        .accessibilityIdentifier(row == 4 && column == 5 ? "angle_unit" : "science_" + scienceIDs[row][column])
                    }
                }
            }
        }
    }
    private func scientificTap(_ row: Int, _ col: Int) {
        if editingExpression { onEditorScientific(row, col); return }
        switch (row, col) {
        case (0,0): calculator.onOpenParenthesis()
        case (0,1): calculator.onCloseParenthesis()
        case (0,2): calculator.onMemoryClear()
        case (0,3): calculator.onMemoryAdd()
        case (0,4): calculator.onMemorySubtract()
        case (0,5): calculator.onMemoryRecall()
        case (1,0): second.toggle()
        case (1,1): calculator.onScientific(.square)
        case (1,2): calculator.onScientific(.cube)
        case (1,3): calculator.onSelectOperator(.Power)
        case (1,4): if second { calculator.onSelectOperator(.ReversePower) } else { calculator.onScientific(.exp) }
        case (1,5): calculator.onScientific(second ? .pow2 : .pow10)
        case (2,0): calculator.onScientific(.reciprocal)
        case (2,1): calculator.onScientific(.squareRoot)
        case (2,2): calculator.onScientific(.cubeRoot)
        case (2,3): calculator.onSelectOperator(.Root)
        case (2,4): if second { calculator.onSelectOperator(.LogBase) } else { calculator.onScientific(.ln) }
        case (2,5): calculator.onScientific(second ? .log2 : .log10)
        case (3,0): calculator.onScientific(.factorial)
        case (3,1): calculator.onScientific(second ? .asin : .sin)
        case (3,2): calculator.onScientific(second ? .acos : .cos)
        case (3,3): calculator.onScientific(second ? .atan : .tan)
        case (3,4): calculator.onScientific(.e)
        case (3,5): calculator.onExponent()
        case (4,0): calculator.onScientific(.random)
        case (4,1): calculator.onScientific(second ? .asinh : .sinh)
        case (4,2): calculator.onScientific(second ? .acosh : .cosh)
        case (4,3): calculator.onScientific(second ? .atanh : .tanh)
        case (4,4): calculator.onScientific(.pi)
        case (4,5): calculator.usesDegrees.toggle()
        default: break
        }
    }
}
struct ContentView: View { var body: some View { CalculatorView() } }
#Preview { ContentView() }
