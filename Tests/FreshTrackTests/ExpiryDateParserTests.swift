import XCTest
@testable import FreshTrack

final class ExpiryDateParserTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Parser anchored to 7 Sep 2026 so plausibility windows are deterministic.
    private func parser(monthFirst: Bool = true) -> ExpiryDateParser {
        ExpiryDateParser(today: day(2026, 9, 7), locale: Locale(identifier: monthFirst ? "en_US" : "en_GB"), calendar: calendar)
    }

    private func ymd(_ date: Date?) -> [Int]? {
        date.map { [calendar.component(.year, from: $0), calendar.component(.month, from: $0), calendar.component(.day, from: $0)] }
    }

    func testIsoDates() {
        XCTAssertEqual(ymd(parser().date(in: "LOT 4471 2026-09-14")), [2026, 9, 14])
        XCTAssertEqual(ymd(parser().date(in: "2026.10.03")), [2026, 10, 3])
    }

    func testDayMonthNameYear() {
        XCTAssertEqual(ymd(parser().date(in: "BEST BY 14 SEP 2026")), [2026, 9, 14])
        XCTAssertEqual(ymd(parser().date(in: "14SEP26")), [2026, 9, 14])
        XCTAssertEqual(ymd(parser().date(in: "Use by 3 October 2026")), [2026, 10, 3])
        XCTAssertEqual(ymd(parser().date(in: "EXP 01-DEC-27")), [2027, 12, 1])
    }

    func testMonthNameDayYear() {
        XCTAssertEqual(ymd(parser().date(in: "SEP 14 2026")), [2026, 9, 14])
        XCTAssertEqual(ymd(parser().date(in: "Best if used by Sept 14, 2026")), [2026, 9, 14])
    }

    func testNumericDatesFollowLocaleThenFallBack() {
        // en_US reads month first.
        XCTAssertEqual(ymd(parser(monthFirst: true).date(in: "09/14/2026")), [2026, 9, 14])
        // 14 cannot be a month, so the other order is used.
        XCTAssertEqual(ymd(parser(monthFirst: true).date(in: "14/09/2026")), [2026, 9, 14])
        // en_GB reads day first.
        XCTAssertEqual(ymd(parser(monthFirst: false).date(in: "14.09.26")), [2026, 9, 14])
        XCTAssertEqual(ymd(parser(monthFirst: false).date(in: "03/10/2026")), [2026, 10, 3])
        XCTAssertEqual(ymd(parser(monthFirst: true).date(in: "03/10/2026")), [2026, 3, 10])
    }

    func testMonthOnlyStampsResolveToEndOfMonth() {
        XCTAssertEqual(ymd(parser().date(in: "BB 09/2026")), [2026, 9, 30])
        XCTAssertEqual(ymd(parser().date(in: "BEST BEFORE FEB 2028")), [2028, 2, 29])
    }

    func testRejectsImplausibleAndInvalidDates() {
        XCTAssertNil(parser().date(in: "PACKED 12/03/2019"), "Years back are packing dates, not expiry dates")
        XCTAssertNil(parser().date(in: "31 FEB 2027"))
        XCTAssertNil(parser().date(in: "13/13/2026"))
        XCTAssertNil(parser().date(in: "NET WT 12 OZ 340 G"))
        XCTAssertNil(parser().date(in: ""))
    }

    func testPicksTheFirstDateWhenSeveralAppear() {
        XCTAssertEqual(ymd(parser().date(in: "BEST BY 14 SEP 2026 · LOT 2026-01-05")), [2026, 9, 14])
    }
}
