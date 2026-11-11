import SwiftUI
import Foundation

struct ConversionUnit: Identifiable {
    let id: String
    let name: String
    let symbol: String
    private let dimension: Dimension?
    private let factor: Double
    private let reciprocal: Bool

    init(_ name: String, _ symbol: String, _ dimension: Dimension) {
        self.id = name; self.name = name; self.symbol = symbol
        self.dimension = dimension; factor = 1; reciprocal = false
    }
    init(_ name: String, _ symbol: String, factor: Double = 1, reciprocal: Bool = false) {
        self.id = name; self.name = name; self.symbol = symbol
        dimension = nil; self.factor = factor; self.reciprocal = reciprocal
    }
    func baseValue(_ value: Double) -> Double {
        if let dimension { return dimension.converter.baseUnitValue(fromValue: value) }
        return reciprocal ? factor / value : value * factor
    }
    func value(fromBase value: Double) -> Double {
        if let dimension { return dimension.converter.value(fromBaseUnitValue: value) }
        return reciprocal ? factor / value : value / factor
    }
}

enum ConversionCategory: String, CaseIterable, Identifiable {
    case angle = "Angle", area = "Area", currency = "Currency", data = "Data", energy = "Energy"
    case force = "Force", fuel = "Fuel", length = "Length", power = "Power", pressure = "Pressure"
    case speed = "Speed", temperature = "Temperature", time = "Time", volume = "Volume", weight = "Weight"
    var id: String { rawValue }
    var units: [ConversionUnit] {
        switch self {
        case .angle: return [.init("Degrees", "°", UnitAngle.degrees), .init("Radians", "rad", UnitAngle.radians), .init("Gradians", "grad", UnitAngle.gradians), .init("Revolutions", "rev", UnitAngle.revolutions)]
        case .area: return [.init("Square meters", "m²", UnitArea.squareMeters), .init("Square kilometers", "km²", UnitArea.squareKilometers), .init("Square centimeters", "cm²", UnitArea.squareCentimeters), .init("Square feet", "ft²", UnitArea.squareFeet), .init("Square inches", "in²", UnitArea.squareInches), .init("Square yards", "yd²", UnitArea.squareYards), .init("Square miles", "mi²", UnitArea.squareMiles), .init("Acres", "ac", UnitArea.acres), .init("Hectares", "ha", UnitArea.hectares)]
        case .currency: return [] // Only currencies present in verified downloaded rates are offered.
        case .data: return [.init("Bits", "bit", factor: 0.125), .init("Bytes", "B"), .init("Kilobytes", "kB", factor: 1e3), .init("Megabytes", "MB", factor: 1e6), .init("Gigabytes", "GB", factor: 1e9), .init("Terabytes", "TB", factor: 1e12), .init("Petabytes", "PB", factor: 1e15), .init("Kibibytes", "KiB", factor: 1024), .init("Mebibytes", "MiB", factor: 1_048_576), .init("Gibibytes", "GiB", factor: 1_073_741_824), .init("Tebibytes", "TiB", factor: 1_099_511_627_776)]
        case .energy: return [.init("Joules", "J", UnitEnergy.joules), .init("Kilojoules", "kJ", UnitEnergy.kilojoules), .init("Calories", "cal", UnitEnergy.calories), .init("Kilocalories", "kcal", UnitEnergy.kilocalories), .init("Kilowatt-hours", "kWh", UnitEnergy.kilowattHours)]
        case .force: return [.init("Newtons", "N"), .init("Kilonewtons", "kN", factor: 1000), .init("Pounds-force", "lbf", factor: 4.4482216152605), .init("Kilograms-force", "kgf", factor: 9.80665), .init("Dynes", "dyn", factor: 0.00001)]
        case .fuel: return [.init("Liters per 100 kilometers", "L/100 km"), .init("Miles per gallon (US)", "mpg US", factor: 235.2145833333333, reciprocal: true), .init("Miles per gallon (UK)", "mpg UK", factor: 282.480936331822, reciprocal: true), .init("Kilometers per liter", "km/L", factor: 100, reciprocal: true)]
        case .length: return [.init("Meters", "m", UnitLength.meters), .init("Feet", "ft", UnitLength.feet), .init("Kilometers", "km", UnitLength.kilometers), .init("Centimeters", "cm", UnitLength.centimeters), .init("Millimeters", "mm", UnitLength.millimeters), .init("Micrometers", "µm", UnitLength.micrometers), .init("Nanometers", "nm", UnitLength.nanometers), .init("Inches", "in", UnitLength.inches), .init("Yards", "yd", UnitLength.yards), .init("Miles", "mi", UnitLength.miles), .init("Nautical miles", "nmi", UnitLength.nauticalMiles)]
        case .power: return [.init("Watts", "W", UnitPower.watts), .init("Kilowatts", "kW", UnitPower.kilowatts), .init("Megawatts", "MW", UnitPower.megawatts), .init("Horsepower", "hp", UnitPower.horsepower)]
        case .pressure: return [.init("Pascals", "Pa", factor: 1), .init("Kilopascals", "kPa", UnitPressure.kilopascals), .init("Bars", "bar", UnitPressure.bars), .init("Millibars", "mbar", UnitPressure.millibars), .init("Pounds per square inch", "psi", UnitPressure.poundsForcePerSquareInch), .init("Millimeters of mercury", "mmHg", UnitPressure.millimetersOfMercury), .init("Atmospheres", "atm", factor: 101325)]
        case .speed: return [.init("Meters per second", "m/s", UnitSpeed.metersPerSecond), .init("Kilometers per hour", "km/h", UnitSpeed.kilometersPerHour), .init("Miles per hour", "mph", UnitSpeed.milesPerHour), .init("Knots", "kn", UnitSpeed.knots), .init("Feet per second", "ft/s", factor: 0.3048)]
        case .temperature: return [.init("Celsius", "°C", UnitTemperature.celsius), .init("Fahrenheit", "°F", UnitTemperature.fahrenheit), .init("Kelvin", "K", UnitTemperature.kelvin)]
        case .time: return [.init("Seconds", "s", UnitDuration.seconds), .init("Minutes", "min", UnitDuration.minutes), .init("Hours", "h", UnitDuration.hours), .init("Milliseconds", "ms", factor: 0.001), .init("Microseconds", "µs", factor: 0.000001), .init("Days", "d", factor: 86400), .init("Weeks", "wk", factor: 604800), .init("Years (365 days)", "yr", factor: 31536000)]
        case .volume: return [.init("Liters", "L", UnitVolume.liters), .init("Milliliters", "mL", UnitVolume.milliliters), .init("Cubic meters", "m³", UnitVolume.cubicMeters), .init("Cubic centimeters", "cm³", UnitVolume.cubicCentimeters), .init("Cubic feet", "ft³", UnitVolume.cubicFeet), .init("Gallons (US)", "gal US", UnitVolume.gallons), .init("Gallons (UK)", "gal UK", UnitVolume.imperialGallons), .init("Quarts (US)", "qt US", UnitVolume.quarts), .init("Pints (US)", "pt US", UnitVolume.pints), .init("Cups (US)", "cup US", UnitVolume.cups), .init("Fluid ounces (US)", "fl oz US", UnitVolume.fluidOunces), .init("Tablespoons (US)", "tbsp US", UnitVolume.tablespoons), .init("Teaspoons (US)", "tsp US", UnitVolume.teaspoons)]
        case .weight: return [.init("Kilograms", "kg", UnitMass.kilograms), .init("Pounds", "lb", UnitMass.pounds), .init("Grams", "g", UnitMass.grams), .init("Milligrams", "mg", UnitMass.milligrams), .init("Ounces", "oz", UnitMass.ounces), .init("Stones", "st", UnitMass.stones), .init("Metric tonnes", "t", UnitMass.metricTons), .init("Short tons (US)", "ton US", UnitMass.shortTons), .init("Carats", "ct", UnitMass.carats)]
        }
    }
}

struct CurrencyRates: Codable {
    let base: String
    let date: String
    let rates: [String: Double]
    var allRates: [String: Double] { rates.merging([base: 1]) { _, new in new } }
    var isValid: Bool {
        base.count == 3 && !date.isEmpty && !rates.isEmpty && rates.allSatisfy { $0.key.count == 3 && $0.value.isFinite && $0.value > 0 }
    }
    func convert(_ value: Double, from: String, to: String) -> Double? {
        guard isValid, value.isFinite, let source = allRates[from], let target = allRates[to] else { return nil }
        let result = value / source * target
        return result.isFinite ? result : nil
    }
}

enum UnitConversion {
    static func convert(_ value: Double, from: ConversionUnit, to: ConversionUnit) -> Double? {
        guard value.isFinite else { return nil }
        if from.id == to.id { return value }
        let base = from.baseValue(value)
        guard base.isFinite else { return nil }
        let result = to.value(fromBase: base)
        return result.isFinite ? result : nil
    }
    static func parse(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: ",", with: "")
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
    static func format(_ value: Double) -> String {
        guard value.isFinite else { return "Unavailable" }
        if value == 0 { return "0" }
        return String(format: "%.12g", locale: Locale(identifier: "en_US_POSIX"), value).lowercased()
    }
}

@MainActor final class CurrencyRateStore: ObservableObject {
    @Published private(set) var snapshot: CurrencyRates?
    @Published private(set) var loading = false
    @Published private(set) var failed = false
    private let defaults: UserDefaults
    private let cacheKey = "Calculator.CurrencyRates.v1"
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: cacheKey), let cached = try? JSONDecoder().decode(CurrencyRates.self, from: data), cached.isValid { snapshot = cached }
    }
    func refresh() async {
        guard !loading else { return }
        loading = true; failed = false
        defer { loading = false }
        do {
            // No amount, identity, credentials, or user input is sent to this public daily-rate endpoint.
            let url = URL(string: "https://api.frankfurter.dev/v1/latest")!
            var request = URLRequest(url: url); request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
            let decoded = try JSONDecoder().decode(CurrencyRates.self, from: data)
            guard decoded.isValid else { throw URLError(.cannotParseResponse) }
            snapshot = decoded; defaults.set(data, forKey: cacheKey)
        } catch { failed = true }
    }
}

struct ConversionPanel: View {
    let input: String
    let onUseValue: (String) -> Void
    @State private var category: ConversionCategory = .length
    @State private var sourceID = "Meters"
    @State private var targetID = "Feet"
    @State private var selection: Selection?
    @StateObject private var currency = CurrencyRateStore()
    private enum Selection: String, Identifiable { case category, source, target; var id: String { rawValue } }
    private var units: [ConversionUnit] {
        if category == .currency {
            return (currency.snapshot?.allRates.keys.sorted() ?? []).map {
                ConversionUnit(Locale.current.localizedString(forCurrencyCode: $0) ?? $0, $0)
            }
        }
        return category.units
    }
    private var source: ConversionUnit? { units.first { $0.id == sourceID } ?? (category == .currency ? units.first { $0.symbol == "USD" } : nil) ?? units.first }
    private var target: ConversionUnit? { units.first { $0.id == targetID } ?? (category == .currency ? units.first { $0.symbol == "EUR" } : nil) ?? units.dropFirst().first ?? units.first }
    private var result: Double? {
        guard let value = UnitConversion.parse(input), let source, let target else { return nil }
        if category == .currency { return currency.snapshot?.convert(value, from: source.symbol, to: target.symbol) }
        return UnitConversion.convert(value, from: source, to: target)
    }
    var body: some View {
        GeometryReader { geometry in
        let rowHeight = max(20, min(36, (geometry.size.height - 37) / 2))
        VStack(spacing: 3) {
            HStack {
                Button { selection = .category } label: {
                    HStack(spacing: 4) { Text(category.rawValue); Image(systemName: "chevron.down").font(.caption2) }
                }.accessibilityIdentifier("conversion.category")
                Spacer()
                if category == .currency {
                    Button { Task { await currency.refresh() } } label: {
                        Text(currency.loading ? "Updating…" : currency.snapshot.map { "\(currency.failed ? "Cached · " : "")\($0.date) · ECB" } ?? "Retry rates")
                            .font(.caption2).lineLimit(1)
                    }.disabled(currency.loading).accessibilityLabel("Refresh daily reference currency rates")
                }
                Button(action: swap) { Image(systemName: "arrow.up.arrow.down") }
                    .disabled(result == nil).accessibilityLabel("Swap conversion units").accessibilityIdentifier("conversion.swap")
            }.font(.subheadline).foregroundStyle(.orange)
            valueRow(UnitConversion.parse(input).map(UnitConversion.format)?.replacingOccurrences(of: "-", with: "−") ?? input, unit: source, selection: .source, height: rowHeight)
            Divider().overlay(Color.white.opacity(0.12))
            valueRow(result.map(UnitConversion.format) ?? (currency.loading && category == .currency ? "Loading…" : "Unavailable"), unit: target, selection: .target, height: rowHeight)
            if geometry.size.height > 130 && category == .currency && currency.snapshot == nil && !currency.loading {
                Text("Currency rates need an internet connection.").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .sheet(item: $selection) { selected in
            ConversionPicker(title: selected == .category ? "Conversion" : "\(category.rawValue) units",
                             options: selected == .category ? ConversionCategory.allCases.map { ($0.rawValue, $0.rawValue) } : units.map { ($0.id, "\($0.name) (\($0.symbol))") },
                             selectedID: selected == .category ? category.rawValue : (selected == .source ? source?.id : target?.id)) { id in
                if selected == .category, let next = ConversionCategory(rawValue: id) {
                    category = next; sourceID = next.units.first?.id ?? ""; targetID = next.units.dropFirst().first?.id ?? ""
                } else if selected == .source { sourceID = id } else { targetID = id }
                selection = nil
            }.presentationDetents([.medium, .large]).preferredColorScheme(.dark)
        }
        .task(id: category) { if category == .currency { await currency.refresh() } }
        }
    }
    private func valueRow(_ value: String, unit: ConversionUnit?, selection selected: Selection, height: CGFloat) -> some View {
        HStack(spacing: 12) {
            Text(value).font(.system(size: min(29, height), weight: .light)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.35)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier(selected == .source ? "conversion.input" : "conversion.output")
            Button { selection = selected } label: {
                HStack(spacing: 4) { Text(unit?.symbol ?? "Unit"); Image(systemName: "chevron.down").font(.caption2) }
                    .font(.subheadline).frame(minWidth: 65, alignment: .trailing)
            }.foregroundStyle(.orange).disabled(units.isEmpty)
                .accessibilityLabel("\(selected == .source ? "From" : "To") \(unit?.name ?? "unit")")
                .accessibilityIdentifier(selected == .source ? "conversion.sourceUnit" : "conversion.targetUnit")
        }.frame(height: height)
    }
    private func swap() {
        guard let result, let source, let target else { return }
        sourceID = target.id; targetID = source.id
        onUseValue(String(result))
    }
}

private struct ConversionPicker: View {
    let title: String
    let options: [(String, String)]
    let selectedID: String?
    let choose: (String) -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search", text: $query)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("conversion.search")
                }.padding(12).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12)).padding()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(options.filter { query.isEmpty || $0.1.localizedCaseInsensitiveContains(query) }, id: \.0) { option in
                            Button { choose(option.0); dismiss() } label: {
                                HStack {
                                    Text(option.1)
                                    Spacer()
                                    if option.0 == selectedID { Image(systemName: "checkmark").foregroundStyle(.orange) }
                                }.padding(.horizontal, 20).padding(.vertical, 16)
                                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).foregroundStyle(.primary)
                                .accessibilityIdentifier("conversion.option." + option.0)
                            Divider().padding(.leading, 20)
                        }
                    }
                }
            }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
