import XCTest
@testable import CategoriesCore

final class MoneyFormattingTests: XCTestCase {
    func testTengeUsesSpaceGroupingAndTrailingSymbol() {
        XCTAssertEqual(MoneyFormatting.tenge(1_875_000), "1\u{202F}875\u{202F}000 ₸")
        XCTAssertEqual(MoneyFormatting.tenge(Decimal(string: "87.44")!), "87.44 ₸")
        XCTAssertEqual(MoneyFormatting.tenge(0), "0 ₸")
        XCTAssertEqual(MoneyFormatting.tenge(-20_000), "-20\u{202F}000 ₸")
    }

    func testTengeCapsAtTwoFractionDigitsWithoutForcingTrailingZeros() {
        XCTAssertEqual(MoneyFormatting.tenge(Decimal(string: "12.5")!), "12.5 ₸")
        XCTAssertEqual(MoneyFormatting.tenge(Decimal(string: "12")!), "12 ₸")
    }
}
