import XCTest
@testable import FreshTrack

final class FoodItemTests: XCTestCase {
    func testDaysUntilExpiryCountsWholeDaysFromToday() {
        XCTAssertEqual(Fixtures.item("a", days: -3).daysUntilExpiry, -3)
        XCTAssertEqual(Fixtures.item("b", days: 0).daysUntilExpiry, 0)
        XCTAssertEqual(Fixtures.item("c", days: 12).daysUntilExpiry, 12)
    }

    func testFreshnessBands() {
        XCTAssertEqual(Fixtures.item("x", days: -1).freshnessStatus, .expired)
        XCTAssertEqual(Fixtures.item("x", days: 0).freshnessStatus, .critical)
        XCTAssertEqual(Fixtures.item("x", days: 1).freshnessStatus, .critical)
        XCTAssertEqual(Fixtures.item("x", days: 2).freshnessStatus, .warning)
        XCTAssertEqual(Fixtures.item("x", days: 4).freshnessStatus, .warning)
        XCTAssertEqual(Fixtures.item("x", days: 5).freshnessStatus, .safe)
    }

    func testExpiryLabels() {
        XCTAssertEqual(Fixtures.item("x", days: -2).expiryLabel, "Expired 2d ago")
        XCTAssertEqual(Fixtures.item("x", days: 0).expiryLabel, "Today")
        XCTAssertEqual(Fixtures.item("x", days: 1).expiryLabel, "Tomorrow")
        XCTAssertEqual(Fixtures.item("x", days: 3).expiryLabel, "3 Days")
    }

    func testPlacementLabelMirrorsRawValue() {
        XCTAssertEqual(Fixtures.item("x", days: 1, placement: .fridgeDoor).placementLabel, "Fridge Door")
        XCTAssertEqual(StoragePlacement.bottomDrawer.icon, "refrigerator")
        XCTAssertEqual(StoragePlacement.freezer.icon, "snowflake")
    }

    func testCodableRoundTripPreservesEveryField() throws {
        var original = Fixtures.item("Greek Yogurt", days: 6, placement: .fridge, category: .dairy)
        original.brand = "Fage"
        original.quantity = "500g"
        original.barcode = "0123456789012"
        original.calendarEventID = "evt-1"
        original.notificationID = "notif-1"

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FoodItem.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testSampleDataIsInternallyConsistent() {
        let names = Set(FoodItem.sampleItems.map(\.name))
        XCTAssertEqual(names.count, FoodItem.sampleItems.count, "Sample item names must be unique; recipes match on name")

        // Every sample recipe ingredient should refer to a real sample item so the
        // recipe chips can show freshness info.
        for recipe in Recipe.sampleRecipes {
            for ingredient in recipe.ingredients {
                XCTAssertTrue(names.contains(ingredient), "\(recipe.name) references unknown ingredient \(ingredient)")
            }
        }
    }
}
