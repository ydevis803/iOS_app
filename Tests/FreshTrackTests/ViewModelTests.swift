import XCTest
@testable import FreshTrack

@MainActor
final class HomeViewModelTests: XCTestCase {
    func testFreshnessScoreAndCountsForSampleData() {
        let store = FoodStore(persistence: InMemoryPersistence())
        let viewModel = HomeViewModel(store: store)

        // Sample data: 3 safe (5+ days), 5 warning (2–4 days), 2 critical (0–1 days).
        XCTAssertEqual(viewModel.safeCount, 3)
        XCTAssertEqual(viewModel.warningCount, 5)
        XCTAssertEqual(viewModel.criticalCount, 2)
        XCTAssertEqual(viewModel.freshnessScore, 30)
        XCTAssertTrue(viewModel.hasExpiringSoon)
        XCTAssertEqual(viewModel.expiringSoonItems.first?.name, "Baby Spinach")
    }

    func testFreshnessScoreIsFullForEmptyPantry() {
        let store = FoodStore(items: [], persistence: InMemoryPersistence())
        let viewModel = HomeViewModel(store: store)
        XCTAssertEqual(viewModel.freshnessScore, 100)
        XCTAssertFalse(viewModel.hasExpiringSoon)
    }

    func testViewModelRepublishesStoreChanges() {
        let store = FoodStore(persistence: InMemoryPersistence())
        let viewModel = HomeViewModel(store: store)
        let changed = expectation(description: "objectWillChange")
        let token = viewModel.objectWillChange.sink { changed.fulfill() }

        store.removeItem(store.items[0])

        wait(for: [changed], timeout: 1)
        token.cancel()
    }
}

@MainActor
final class ShoppingListViewModelTests: XCTestCase {
    func testAddTrimsWhitespaceAndRejectsBlankInput() {
        let store = FoodStore(shoppingList: [], persistence: InMemoryPersistence())
        let viewModel = ShoppingListViewModel(store: store)

        XCTAssertFalse(viewModel.add(named: "   "))
        XCTAssertTrue(viewModel.items.isEmpty)

        XCTAssertTrue(viewModel.add(named: "  Bananas "))
        XCTAssertEqual(viewModel.items.map(\.name), ["Bananas"])
        XCTAssertTrue(viewModel.isLast(viewModel.items[0]))
    }
}

@MainActor
final class RecipesViewModelTests: XCTestCase {
    func testIngredientInfoLooksUpPantryItem() {
        let store = FoodStore(
            items: [Fixtures.item("Carrots", days: 3)],
            persistence: InMemoryPersistence()
        )
        let viewModel = RecipesViewModel(store: store)

        let known = viewModel.ingredientInfo(name: "Carrots")
        XCTAssertEqual(known.label, "Carrots (3 days)")
        XCTAssertEqual(known.status, .warning)

        let unknown = viewModel.ingredientInfo(name: "Saffron")
        XCTAssertEqual(unknown.label, "Saffron")
        XCTAssertNil(unknown.status)
    }
}

@MainActor
final class CalendarViewModelTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testDaysInMonthPadsToWeekdayAndFullRows() {
        let store = FoodStore(items: [], persistence: InMemoryPersistence())
        let viewModel = CalendarViewModel(store: store)
        viewModel.displayedMonth = date(2026, 1, 15) // January 2026 starts on a Thursday

        let days = viewModel.daysInMonth()
        let leadingBlanks = days.prefix { $0 == nil }.count
        let realDays = days.compactMap { $0 }

        XCTAssertEqual(leadingBlanks, 4)
        XCTAssertEqual(realDays.count, 31)
        XCTAssertEqual(days.count % 7, 0)
        XCTAssertEqual(viewModel.dayNumber(for: realDays[0]), 1)
        XCTAssertEqual(viewModel.dayNumber(for: realDays[30]), 31)
        XCTAssertTrue(realDays.allSatisfy(viewModel.isInDisplayedMonth))
    }

    func testMonthNavigationAndTitle() {
        let store = FoodStore(items: [], persistence: InMemoryPersistence())
        let viewModel = CalendarViewModel(store: store)
        viewModel.displayedMonth = date(2026, 1, 15)

        viewModel.nextMonth()
        XCTAssertEqual(Calendar.current.component(.month, from: viewModel.displayedMonth), 2)
        viewModel.previousMonth()
        viewModel.previousMonth()
        XCTAssertEqual(Calendar.current.component(.year, from: viewModel.displayedMonth), 2025)
        XCTAssertEqual(Calendar.current.component(.month, from: viewModel.displayedMonth), 12)
    }

    func testSelectionAndDotsReflectStore() {
        let target = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let store = FoodStore(
            items: [Fixtures.item("Milk", days: 1), Fixtures.item("Rice", days: 1), Fixtures.item("Far", days: 9)],
            persistence: InMemoryPersistence()
        )
        let viewModel = CalendarViewModel(store: store)

        XCTAssertFalse(viewModel.isSelected(target))
        viewModel.selectedDate = target
        XCTAssertTrue(viewModel.isSelected(target))

        let items = viewModel.items(expiringOn: target)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(viewModel.expiringDots(for: items).count, 2)
    }
}
