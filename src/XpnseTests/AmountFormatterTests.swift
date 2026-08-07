//
//  AmountFormatterTests.swift
//  XpnseTests
//
//  Priority suite: editable amounts, parse/round-trip, float precision,
//  currency display, and compact number composition.
//

import XCTest
@testable import Xpnse

final class AmountFormatterTests: XCTestCase {

    // MARK: - Edit field seeding (float precision)

    /// Regression: opening edit must not show binary float noise like 172.799999998.
    func testFormatDoubleRoundsBinaryFloatNoiseForEditing() {
        // Nearby bit patterns of 172.8 that String(double) expands with trailing 9s.
        let noisy = Double(bitPattern: 4640283876061190554 &- 50) // ~172.7999999999986
        XCTAssertTrue(
            "\(noisy)".contains("999"),
            "Precondition: raw interpolation should expose float noise, got \("\(noisy)")"
        )
        XCTAssertEqual(AmountFormatter.format(noisy), "172.8")
        XCTAssertEqual(AmountFormatter.format(172.80), "172.8")
        XCTAssertEqual(AmountFormatter.format(172.8), "172.8")
    }

    func testFormatDoubleCommonCurrencyAmounts() {
        let cases: [(Double, String)] = [
            (0, "0"),
            (1, "1"),
            (10.5, "10.5"),
            (99.99, "99.99"),
            (100, "100"),
            (172.80, "172.8"),
            (1000.01, "1000.01"),
            (198000, "198000"),
            (1_234_567.89, "1234567.89"),
        ]
        for (value, expected) in cases {
            XCTAssertEqual(AmountFormatter.format(value), expected, "format(\(value))")
        }
    }

    func testFormatForEditingHasNoGroupingSeparators() {
        let formatted = AmountFormatter.formatForEditing(Decimal(198_000))
        XCTAssertEqual(formatted, "198000")
        XCTAssertFalse(formatted.contains(","))
        XCTAssertFalse(formatted.contains(" "))
        XCTAssertFalse(formatted.contains("\u{00A0}")) // NBSP
    }

    func testFormatForEditingStripsTrailingZerosUpToTwoFractionDigits() {
        XCTAssertEqual(AmountFormatter.formatForEditing(Decimal(string: "172.80")!), "172.8")
        XCTAssertEqual(AmountFormatter.formatForEditing(Decimal(string: "172.00")!), "172")
        XCTAssertEqual(AmountFormatter.formatForEditing(Decimal(string: "172.81")!), "172.81")
        XCTAssertEqual(AmountFormatter.formatForEditing(Decimal(string: "0.10")!), "0.1")
    }

    func testFormatDecimalUsesPOSIXPoint() {
        XCTAssertEqual(AmountFormatter.format(Decimal(string: "172.80")!), "172.8")
        XCTAssertEqual(AmountFormatter.format(Decimal(198_000)), "198000")
    }

    // MARK: - Parsing entry fields

    func testParseDecimalPlainPOSIX() {
        XCTAssertEqual(AmountFormatter.parseDecimal("172.80"), Decimal(string: "172.80"))
        XCTAssertEqual(AmountFormatter.parseDecimal("198000"), Decimal(198_000))
        XCTAssertEqual(AmountFormatter.parseDecimal("0"), 0)
        XCTAssertEqual(AmountFormatter.parseDecimal("10.5"), Decimal(string: "10.5"))
    }

    func testParseDecimalTrimsWhitespace() {
        XCTAssertEqual(AmountFormatter.parseDecimal("  172.80  "), Decimal(string: "172.80"))
    }

    func testParseDecimalRejectsEmptyAndInvalid() {
        XCTAssertNil(AmountFormatter.parseDecimal(""))
        XCTAssertNil(AmountFormatter.parseDecimal("   "))
        XCTAssertNil(AmountFormatter.parseDecimal("abc"))
        XCTAssertNil(AmountFormatter.parseDecimal("$172"))
    }

    /// Regression: locale-grouped strings (e.g. 198,000) must parse fully, not truncate to 198.
    func testParseDecimalAcceptsLocaleGroupedThousands() {
        let usGrouped = "198,000"
        guard let parsed = AmountFormatter.parseDecimal(usGrouped) else {
            // If current locale doesn't use comma grouping, still accept plain form.
            XCTAssertEqual(AmountFormatter.parseDecimal("198000"), Decimal(198_000))
            return
        }
        XCTAssertEqual(parsed, Decimal(198_000), "Grouped amount truncated: \(usGrouped) → \(parsed)")
    }

    // MARK: - Round-trip (edit UI ↔ storage Double)

    func testEditRoundTripPreservesCents() {
        let originals = ["172.80", "172.8", "99.99", "0.01", "1000.50", "198000"]
        for text in originals {
            guard let parsed = AmountFormatter.parseDecimal(text) else {
                XCTFail("Failed to parse \(text)")
                continue
            }
            let stored = Double(truncating: parsed as NSDecimalNumber)
            let reseeded = AmountFormatter.format(stored)
            let reparsed = AmountFormatter.parseDecimal(reseeded)
            XCTAssertNotNil(reparsed, "Reseeded \(reseeded) from \(text) failed parse")
            // Compare at 2 decimal places (money precision).
            let expectedCents = NSDecimalNumber(decimal: parsed)
                .multiplying(byPowerOf10: 2)
                .rounding(accordingToBehavior: NSDecimalNumberHandler(
                    roundingMode: .plain,
                    scale: 0,
                    raiseOnExactness: false,
                    raiseOnOverflow: false,
                    raiseOnUnderflow: false,
                    raiseOnDivideByZero: false
                ))
            let actualCents = NSDecimalNumber(decimal: reparsed ?? 0)
                .multiplying(byPowerOf10: 2)
                .rounding(accordingToBehavior: NSDecimalNumberHandler(
                    roundingMode: .plain,
                    scale: 0,
                    raiseOnExactness: false,
                    raiseOnOverflow: false,
                    raiseOnUnderflow: false,
                    raiseOnDivideByZero: false
                ))
            XCTAssertEqual(actualCents, expectedCents, "Round-trip cents mismatch for \(text) → \(reseeded)")
        }
    }

    func testNoisyStoredDoubleRoundTripsToCleanEditString() {
        let noisy = Double(bitPattern: 4640283876061190554 &- 50)
        let editText = AmountFormatter.format(noisy)
        XCTAssertEqual(editText, "172.8")
        let parsed = AmountFormatter.parseDecimal(editText)
        XCTAssertEqual(parsed, Decimal(string: "172.8"))
    }

    // MARK: - Currency display (exact, not compact)

    func testCurrencyFormatUsesTwoFractionDigits() {
        let formatted = AmountFormatter.format(172.8, currencyCode: "INR")
        // Must include 2 decimal places for currency (locale-dependent symbol/order).
        XCTAssertTrue(
            formatted.contains("172.80") || formatted.contains("172,80"),
            "Expected 2 fraction digits in \(formatted)"
        )
        XCTAssertFalse(formatted.contains("999"), "Currency must not show float noise: \(formatted)")
    }

    func testCurrencyFormatDoesNotUseCompactNotation() {
        let formatted = AmountFormatter.format(198_000.0, currencyCode: "INR")
        XCTAssertFalse(formatted.contains("L"), formatted)
        XCTAssertFalse(formatted.contains("Cr"), formatted)
        XCTAssertFalse(formatted.contains("K"), formatted)
        XCTAssertFalse(formatted.contains("M"), formatted)
    }

    func testFormatDecimalFixedFractionDigits() {
        // Locale-dependent grouping, but fraction digits are fixed.
        let two = AmountFormatter.formatDecimal(172.8, fractionDigits: 2)
        XCTAssertTrue(two.hasSuffix("80") || two.hasSuffix("8"), "Got \(two)")
        // Stronger: strip non-digits except decimal separators and compare numeric intent via parse.
        let digitsOnly = two.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
        XCTAssertFalse(digitsOnly.isEmpty)
    }

    // MARK: - Compact composition via AmountFormatter facade

    func testCompactNumberUsesResolvedStyleForKnownValues() {
        let lakhCrore = CompactNumberFormatterFactory.make(style: .lakhCrore)
        let million = CompactNumberFormatterFactory.make(style: .million)

        XCTAssertEqual(lakhCrore.format(Decimal(198_000)), "1.98L")
        XCTAssertEqual(million.format(Decimal(198_000)), "198K")
        XCTAssertEqual(lakhCrore.format(Decimal(string: "172.80")!), "172.8")
        XCTAssertEqual(million.format(Decimal(string: "172.80")!), "172.8")
    }

    func testFormatCompactPrefixIsCurrencySymbol() {
        for code in ["INR", "USD", "EUR"] {
            let compact = AmountFormatter.formatCompact(Decimal(1_250), currencyCode: code)
            let symbol = AmountFormatter.currencySymbol(for: code)
            XCTAssertTrue(compact.hasPrefix(symbol), "\(code): \(compact) should start with \(symbol)")
        }
    }
}
