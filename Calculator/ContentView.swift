// Adapted from bofeiw/ios-calculator-clone-for-ipados (CC0-1.0).
import SwiftUI

struct CalculatorView: View {
    @State private var calculator = CalculatorModel()
    @AppStorage("leftHandedLayout") private var leftHanded = false
    @AppStorage("calculationHistory") private var storedHistory = Data()
    @State private var showingHistory = false
    @State private var second = false
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
            let scientific = modeOverride ?? automatic
            let layout = CalculatorLayout(availableSize: geometry.size, scientific: scientific)
            VStack(spacing: 0) {
                if scientific {
                    HStack {
                        Button { showingHistory = true } label: {
                            Image(systemName: "clock.arrow.circlepath").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("History").accessibilityIdentifier("calculator_history")
                        Spacer()
                        Menu {
                            Button { modeOverride = false } label: { Label("Basic", systemImage: "plus.forwardslash.minus") }
                            Button { modeOverride = true } label: { Label("Scientific", systemImage: "function") }
                            Button { modeOverride = nil } label: { Label("Automatic", systemImage: "iphone.gen3.radiowaves.left.and.right") }
                            Divider()
                            Toggle("Left-handed", isOn: $leftHanded).accessibilityIdentifier("left_handed_toggle")
                        } label: {
                            Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Calculator mode and settings").accessibilityIdentifier("calculator_settings")
                    }
                    .font(.system(size: 20)).foregroundStyle(.white)
                    .padding(.bottom, 8)
                }
                Spacer(minLength: 0)
                VStack(spacing: layout.gap * 1.5) {
                    if scientific {
                        scientificDisplay(layout)
                    } else {
                        DisplayArea(eventCallback: onDisplayAreaClick, currentDisplay: calculator.displayedValue, buttonSize: layout.buttonSize)
                            .contextMenu {
                                Button("Copy", systemImage: "doc.on.doc") { onDisplayAreaClick(.CopyToClipBoard) }
                                Button("Paste", systemImage: "doc.on.clipboard") { onDisplayAreaClick(.Paste) }
                                Button("Scientific") { modeOverride = true }
                                Button("History") { showingHistory = true }
                            }
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
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            .onChange(of: scientific, initial: true) { _, value in calculator.isScientificMode = value }
            .onChange(of: automatic) { _, _ in modeOverride = nil }
        }
        .background(Color.black.ignoresSafeArea()).preferredColorScheme(.dark).statusBarHidden(true)
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            if let entries = try? JSONDecoder().decode([CalculatorModel.HistoryEntry].self, from: storedHistory) { calculator.loadHistory(entries) }
        }
        .onChange(of: calculator.history.map(\.id)) { _, _ in
            if let data = try? JSONEncoder().encode(calculator.history) { storedHistory = data }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let orientation = UIDevice.current.orientation
            if orientation.isLandscape || orientation.isPortrait { deviceIsLandscape = orientation.isLandscape }
        }
        .sheet(isPresented: $showingHistory) { historyView }
    }

    private func scientificDisplay(_ layout: CalculatorLayout) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(calculator.expression.isEmpty ? calculator.displayedValue : calculator.expression)
                .font(.system(size: layout.buttonHeight * 0.72, weight: .light))
                .lineLimit(1).minimumScaleFactor(0.2)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("calculator_expression")
            Text(calculator.previewValue ?? calculator.displayedValue)
                .font(.system(size: layout.buttonHeight * 0.42, weight: .light))
                .foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.2)
                .accessibilityIdentifier("calculator_display")
                .accessibilityLabel("Result").accessibilityValue(calculator.previewValue ?? calculator.displayedValue)
        }
        .frame(height: layout.displayHeight, alignment: .bottomTrailing)
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { onDisplayAreaClick(.CopyToClipBoard) }
            Button("Paste", systemImage: "doc.on.clipboard") { onDisplayAreaClick(.Paste) }
        }
        .gesture(DragGesture(minimumDistance: 35).onEnded { if abs($0.translation.width) > abs($0.translation.height) { calculator.onDelete() } })
    }
    private var historyView: some View {
        NavigationStack {
            List {
                if calculator.history.isEmpty { Text("No calculations yet").foregroundStyle(.secondary) }
                ForEach(calculator.history) { item in
                    Button {
                        calculator.restoreHistory(item.id)
                        showingHistory = false
                    } label: {
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(item.expression).foregroundStyle(.secondary)
                            Text(item.result).font(.title2).foregroundStyle(.white)
                        }.frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Clear") { calculator.clearHistory() }.disabled(calculator.history.isEmpty) }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { showingHistory = false } }
            }
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
