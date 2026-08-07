//
//  CompactNumberFormatterTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class CompactNumberFormatterTests: XCTestCase {
    private let lakhCrore = CompactNumberFormatterFactory.make(style: .lakhCrore)
    private let million = CompactNumberFormatterFactory.make(style: .million)

    func testLakhCroreThresholds() {
        let cases: [(Decimal, String)] = [
            (999, "999"),
            (1000, "1K"),
            (1250, "1.25K"),
            (99999, "100K"),
            (100000, "1L"),
            (125000, "1.25L"),
            (999999, "10L"),
            (1000000, "10L"),
            (1250000, "12.5L"),
            (9999999, "100L"),
            (10000000, "1Cr"),
            (12500000, "1.25Cr"),
            (100000000, "10Cr"),
        ]
        for (value, expected) in cases {
            XCTAssertEqual(lakhCrore.format(value), expected, "Lakh/Crore \(value)")
        }
    }

    func testMillionThresholds() {
        let cases: [(Decimal, String)] = [
            (999, "999"),
            (1000, "1K"),
            (1250, "1.25K"),
            (999999, "1000K"),
            (1000000, "1M"),
            (1250000, "1.25M"),
            (999999999, "1000M"),
            (1000000000, "1B"),
            (2500000000, "2.5B"),
            (4800000000000, "4.8T"),
        ]
        for (value, expected) in cases {
            XCTAssertEqual(million.format(value), expected, "Million \(value)")
        }
    }

    func testNegativeValues() {
        XCTAssertEqual(lakhCrore.format(-999), "-999")
        XCTAssertEqual(lakhCrore.format(-1000), "-1K")
        XCTAssertEqual(lakhCrore.format(-125000), "-1.25L")
        XCTAssertEqual(lakhCrore.format(-1250000), "-12.5L")

        XCTAssertEqual(million.format(-999), "-999")
        XCTAssertEqual(million.format(-1000), "-1K")
        XCTAssertEqual(million.format(-125000), "-125K")
        XCTAssertEqual(million.format(-1250000), "-1.25M")
    }

    func testZero() {
        XCTAssertEqual(lakhCrore.format(0), "0")
        XCTAssertEqual(million.format(0), "0")
    }

    func testDecimalValues() {
        XCTAssertEqual(lakhCrore.format(Decimal(string: "1250.50")!), "1.25K")
        XCTAssertEqual(lakhCrore.format(Decimal(string: "125000.75")!), "1.25L")
        XCTAssertEqual(million.format(Decimal(string: "1250.50")!), "1.25K")
        XCTAssertEqual(million.format(Decimal(string: "125000.75")!), "125K")
    }

    func testTrailingZerosStripped() {
        XCTAssertEqual(lakhCrore.format(120000), "1.2L")
        XCTAssertEqual(lakhCrore.format(50000000), "5Cr")
        XCTAssertEqual(million.format(2500000), "2.5M")
        XCTAssertEqual(million.format(25000), "25K")
    }

    func testLakhCroreBoundaryTransitions() {
        XCTAssertEqual(lakhCrore.format(999), "999")
        XCTAssertEqual(lakhCrore.format(1000), "1K")
        XCTAssertEqual(lakhCrore.format(99999), "100K")
        XCTAssertEqual(lakhCrore.format(100000), "1L")
        XCTAssertEqual(lakhCrore.format(999999), "10L")
        XCTAssertEqual(lakhCrore.format(1000000), "10L")
        XCTAssertEqual(lakhCrore.format(9999999), "100L")
        XCTAssertEqual(lakhCrore.format(10000000), "1Cr")
    }

    func testPreferenceStyleResolution() {
        let indiaLocale = Locale(identifier: "en_IN")
        XCTAssertEqual(NumberFormatPreference.style(for: indiaLocale), .lakhCrore)

        let usLocale = Locale(identifier: "en_US")
        XCTAssertEqual(NumberFormatPreference.style(for: usLocale), .million)

        XCTAssertEqual(NumberFormatPreference.lakhCrore.resolvedStyle, .lakhCrore)
        XCTAssertEqual(NumberFormatPreference.million.resolvedStyle, .million)
    }

    func testSalaryAmountDoesNotRoundUpToWholeLakh() {
        // Regression: 198000 must be 1.98L, not Apple compactName's 2L.
        XCTAssertEqual(lakhCrore.format(Decimal(198_000)), "1.98L")
        XCTAssertEqual(million.format(Decimal(198_000)), "198K")
    }

    func testSubThousandKeepsTwoFractionDigitsWhenNeeded() {
        XCTAssertEqual(lakhCrore.format(Decimal(string: "172.80")!), "172.8")
        XCTAssertEqual(million.format(Decimal(string: "99.99")!), "99.99")
    }

    func testFormatCompactComposesCurrencySymbol() {
        let compact = AmountFormatter.formatCompact(
            Decimal(125000),
            currencyCode: "INR"
        )
        let symbol = AmountFormatter.currencySymbol(for: "INR")
        XCTAssertTrue(compact.hasPrefix(symbol), "Expected \(compact) to start with \(symbol)")
        XCTAssertTrue(
            compact.hasSuffix("1.25L") || compact.hasSuffix("125K"),
            "Unexpected compact body in \(compact)"
        )
    }

    func testExactCurrencyFormattingIndependentOfCompact() {
        let exact = AmountFormatter.format(125000.0, currencyCode: "INR")
        XCTAssertFalse(exact.contains("L"))
        XCTAssertFalse(exact.contains("K"))
        XCTAssertFalse(exact.contains("Cr"))
    }

    func testCurrencyIndependentOfNumberStyle() {
        let lakhUSD = "\(AmountFormatter.currencySymbol(for: "USD"))\(lakhCrore.format(Decimal(125000)))"
        let millionINR = "\(AmountFormatter.currencySymbol(for: "INR"))\(million.format(Decimal(125000)))"
        XCTAssertTrue(lakhUSD.hasSuffix("1.25L"), lakhUSD)
        XCTAssertTrue(millionINR.hasSuffix("125K"), millionINR)
    }
}
