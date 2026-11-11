import XCTest
@testable import Calculator

final class ConversionTests: XCTestCase {
    private func convert(_ value: Double, _ category: ConversionCategory, _ from: String, _ to: String) -> Double? {
        guard let source = category.units.first(where: { $0.symbol == from }),
              let target = category.units.first(where: { $0.symbol == to }) else {
            XCTFail("Missing units: \(category) \(from) \(to)"); return nil
        }
        return UnitConversion.convert(value, from: source, to: target)
    }
    private func assertConversion(_ value: Double, _ category: ConversionCategory, _ from: String, _ to: String, _ expected: Double, accuracy: Double = 0.0001, file: StaticString = #filePath, line: UInt = #line) {
        guard let result = convert(value, category, from, to) else { XCTFail("Conversion failed", file: file, line: line); return }
        XCTAssertEqual(result, expected, accuracy: accuracy, file: file, line: line)
    }
    func testEveryStandardCategoryExists() {
        XCTAssertEqual(ConversionCategory.allCases.count, 15)
        for category in ConversionCategory.allCases where category != .currency {
            XCTAssertGreaterThanOrEqual(category.units.count, 3)
            XCTAssertEqual(Set(category.units.map(\.id)).count, category.units.count)
        }
        XCTAssertTrue(ConversionCategory.currency.units.isEmpty, "Currency choices require real rates")
    }
    func testLengthAreaVolumeAndWeight() {
        assertConversion(1, .length, "ft", "m", 0.3048)
        assertConversion(1, .length, "mi", "km", 1.609344)
        assertConversion(1, .area, "ha", "m²", 10000)
        assertConversion(1, .area, "ft²", "m²", 0.09290304)
        assertConversion(1, .volume, "gal US", "L", 3.785411784)
        assertConversion(1, .volume, "gal UK", "L", 4.54609)
        assertConversion(1, .weight, "lb", "kg", 0.45359237)
    }
    func testNegativeAndAffineTemperatures() {
        assertConversion(0, .temperature, "°C", "°F", 32)
        assertConversion(-40, .temperature, "°C", "°F", -40)
        assertConversion(212, .temperature, "°F", "°C", 100)
        assertConversion(-273.15, .temperature, "°C", "K", 0)
        assertConversion(0, .temperature, "K", "°C", -273.15)
    }
    func testAngleEnergyForcePowerPressureAndSpeed() {
        assertConversion(180, .angle, "°", "rad", .pi)
        assertConversion(1, .energy, "kWh", "J", 3_600_000)
        assertConversion(1, .force, "lbf", "N", 4.4482216152605)
        assertConversion(1, .power, "kW", "W", 1000)
        assertConversion(1, .pressure, "bar", "Pa", 100000)
        assertConversion(1, .pressure, "atm", "kPa", 101.325)
        assertConversion(36, .speed, "km/h", "m/s", 10)
    }
    func testFuelUsesReciprocalConversion() {
        assertConversion(10, .fuel, "L/100 km", "mpg US", 23.5214583333)
        assertConversion(23.5214583333, .fuel, "mpg US", "L/100 km", 10)
        assertConversion(10, .fuel, "L/100 km", "km/L", 10)
        XCTAssertNil(convert(0, .fuel, "L/100 km", "mpg US"))
        XCTAssertNil(convert(0, .fuel, "mpg US", "L/100 km"))
    }
    func testDataDistinguishesDecimalAndBinary() {
        assertConversion(1, .data, "B", "bit", 8)
        assertConversion(1, .data, "MB", "B", 1_000_000)
        assertConversion(1, .data, "MiB", "B", 1_048_576)
        assertConversion(1, .data, "GiB", "MiB", 1024)
        assertConversion(1, .data, "kB", "KiB", 0.9765625)
    }
    func testTimeDefinitionsAreExplicit() {
        assertConversion(1, .time, "wk", "h", 168)
        assertConversion(1, .time, "yr", "d", 365)
        assertConversion(1000, .time, "ms", "s", 1)
    }
    func testEveryUnitRoundTripsThroughItsCategory() {
        for category in ConversionCategory.allCases where category != .currency {
            let units = category.units
            for source in units {
                guard let converted = UnitConversion.convert(12.345, from: source, to: units[0]),
                      let returned = UnitConversion.convert(converted, from: units[0], to: source) else {
                    XCTFail("Failed \(category.rawValue): \(source.name)"); continue
                }
                XCTAssertEqual(returned, 12.345, accuracy: 0.000001, "\(category.rawValue): \(source.name)")
            }
        }
    }
    func testCurrencyFixtureCrossRatesBaseAndNegativeAmounts() throws {
        let data = Data(#"{"base":"EUR","date":"2026-01-02","rates":{"USD":1.2,"GBP":0.8,"JPY":160}}"#.utf8)
        let rates = try JSONDecoder().decode(CurrencyRates.self, from: data)
        XCTAssertTrue(rates.isValid)
        XCTAssertEqual(try XCTUnwrap(rates.convert(100, from: "USD", to: "GBP")), 66.6666666667, accuracy: 0.000001)
        XCTAssertEqual(rates.convert(100, from: "EUR", to: "USD"), 120)
        XCTAssertEqual(rates.convert(-100, from: "EUR", to: "GBP"), -80)
        XCTAssertEqual(rates.convert(0, from: "USD", to: "GBP"), 0)
        XCTAssertEqual(rates.convert(12, from: "USD", to: "USD"), 12)
        XCTAssertNil(rates.convert(1, from: "UNKNOWN", to: "EUR"))
        XCTAssertNil(rates.convert(.infinity, from: "EUR", to: "USD"))
    }
    func testInvalidCurrencyRatesAreRejected() {
        for invalid in [0.0, -1, Double.infinity, Double.nan] {
            let rates = CurrencyRates(base: "EUR", date: "2026-01-02", rates: ["USD": invalid])
            XCTAssertFalse(rates.isValid)
            XCTAssertNil(rates.convert(10, from: "EUR", to: "USD"))
        }
        XCTAssertFalse(CurrencyRates(base: "EUR", date: "", rates: [:]).isValid)
    }
    @MainActor func testOnlyVerifiedCachedRatesAreLoaded() throws {
        let suite = "ConversionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertNil(CurrencyRateStore(defaults: defaults).snapshot)
        defaults.set(Data("invalid".utf8), forKey: "Calculator.CurrencyRates.v1")
        XCTAssertNil(CurrencyRateStore(defaults: defaults).snapshot)
        let fixture = CurrencyRates(base: "EUR", date: "2026-01-02", rates: ["USD": 1.2])
        defaults.set(try JSONEncoder().encode(fixture), forKey: "Calculator.CurrencyRates.v1")
        XCTAssertEqual(CurrencyRateStore(defaults: defaults).snapshot?.date, "2026-01-02")
    }
    func testParsingFormattingAndNonfiniteGuards() {
        XCTAssertEqual(UnitConversion.parse("−12.5"), -12.5)
        XCTAssertEqual(UnitConversion.parse("1,234.5"), 1234.5)
        XCTAssertEqual(UnitConversion.parse("1e-20"), 1e-20)
        for invalid in ["Error", "nan", "inf", "1/0", "", "1e999"] { XCTAssertNil(UnitConversion.parse(invalid)) }
        XCTAssertEqual(UnitConversion.format(-0.0), "0")
        XCTAssertEqual(UnitConversion.format(1e-20), "1e-20")
        XCTAssertEqual(UnitConversion.format(.infinity), "Unavailable")
        XCTAssertNil(convert(.infinity, .length, "ft", "m"))
        XCTAssertNil(convert(Double.greatestFiniteMagnitude, .length, "km", "mm"))
        assertConversion(-10, .length, "m", "cm", -1000)
    }
}
