import XCTest
@testable import FreshTrack

final class ShelfLifeEstimatorTests: XCTestCase {
    func testEveryCategoryHasAPositiveEstimateAndSubject() {
        for category in FoodCategory.allCases {
            XCTAssertGreaterThan(ShelfLifeEstimator.days(for: category), 0, "\(category)")
            XCTAssertFalse(ShelfLifeEstimator.subject(for: category).isEmpty, "\(category)")
        }
    }

    func testPerishablesExpireSoonerThanShelfStable() {
        XCTAssertLessThan(ShelfLifeEstimator.days(for: .meat), ShelfLifeEstimator.days(for: .produce))
        XCTAssertLessThan(ShelfLifeEstimator.days(for: .produce), ShelfLifeEstimator.days(for: .grain))
        XCTAssertLessThan(ShelfLifeEstimator.days(for: .dairy), ShelfLifeEstimator.days(for: .frozen))
    }

    func testEstimatedExpiryCountsFromTheGivenDate() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))!
        let expiry = ShelfLifeEstimator.estimatedExpiry(for: .produce, from: start, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.day], from: start, to: expiry).day, ShelfLifeEstimator.days(for: .produce))
    }
}
