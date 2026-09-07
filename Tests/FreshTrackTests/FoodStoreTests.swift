import XCTest
@testable import FreshTrack

@MainActor
final class FoodStoreTests: XCTestCase {
    private func makeStore(
        items: [FoodItem] = FoodItem.sampleItems,
        shoppingList: [ShoppingItem] = ShoppingItem.sampleItems,
        persistence: InMemoryPersistence = InMemoryPersistence()
    ) -> FoodStore {
        FoodStore(items: items, shoppingList: shoppingList, persistence: persistence)
    }

    // MARK: Init / persistence

    func testInitFallsBackToSeedDataWhenNothingPersisted() {
        let store = makeStore()
        XCTAssertEqual(store.items.count, FoodItem.sampleItems.count)
        XCTAssertEqual(store.shoppingList.count, ShoppingItem.sampleItems.count)
    }

    func testInitPrefersPersistedData() {
        let saved = [Fixtures.item("Persisted", days: 3)]
        let persistence = InMemoryPersistence(items: saved, shoppingList: [ShoppingItem(name: "Bread")])
        let store = makeStore(persistence: persistence)

        XCTAssertEqual(store.items, saved)
        XCTAssertEqual(store.shoppingList.map(\.name), ["Bread"])
    }

    func testRemoveItemDropsItAndPersists() {
        let persistence = InMemoryPersistence()
        let store = makeStore(persistence: persistence)
        let victim = store.items[0]

        store.removeItem(victim)

        XCTAssertFalse(store.items.contains(victim))
        XCTAssertEqual(store.items.count, FoodItem.sampleItems.count - 1)
        XCTAssertEqual(persistence.loadItems()?.count, FoodItem.sampleItems.count - 1)
    }

    // MARK: Expiry queries

    func testExpiringSoonKeepsOnlyZeroToFourDaysSortedSoonestFirst() {
        let store = makeStore(items: [
            Fixtures.item("far", days: 5),
            Fixtures.item("four", days: 4),
            Fixtures.item("expired", days: -1),
            Fixtures.item("today", days: 0),
            Fixtures.item("two", days: 2)
        ])

        XCTAssertEqual(store.expiringSoonItems.map(\.name), ["today", "two", "four"])
    }

    func testSortedItemsOrdersBySoonestExpiry() {
        let store = makeStore(items: [
            Fixtures.item("c", days: 9),
            Fixtures.item("a", days: -2),
            Fixtures.item("b", days: 1)
        ])
        XCTAssertEqual(store.sortedItems.map(\.name), ["a", "b", "c"])
    }

    func testItemsExpiringOnDateMatchesCalendarDay() {
        let target = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let store = makeStore(items: [
            Fixtures.item("hit", days: 3),
            Fixtures.item("miss", days: 4)
        ])
        XCTAssertEqual(store.items(expiringOn: target).map(\.name), ["hit"])
    }

    // MARK: Recipes

    func testBatchCookingRequiresThreeExpiringIngredients() {
        let store = makeStore()
        let names = Set(store.batchCookingRecipes.map(\.name))

        // With the bundled sample data only these two recipes have 3 ingredients
        // inside the 0–4 day window (Celery is 5 days, Yogurt 6, Almond Milk 8).
        XCTAssertEqual(names, ["Classic Pot Roast", "Avocado Toast Brunch"])
    }

    func testScoredRecipesAreSortedByMatchCountDescending() {
        let store = makeStore()
        let counts = store.scoredRecipes.map(\.matchCount)

        XCTAssertEqual(counts, counts.sorted(by: >))
        XCTAssertEqual(counts.first, 3)
        XCTAssertEqual(store.scoredRecipes.count, Recipe.sampleRecipes.count)

        let smoothie = store.scoredRecipes.first { $0.recipe.name == "Yogurt Smoothie Bowl" }
        XCTAssertEqual(smoothie?.matchingIngredients, ["Baby Spinach"])
    }

    func testNoRecipesMatchWhenPantryIsFresh() {
        let store = makeStore(items: [Fixtures.item("Beef Chuck", days: 30)])
        XCTAssertTrue(store.batchCookingRecipes.isEmpty)
        XCTAssertTrue(store.scoredRecipes.allSatisfy { $0.matchCount == 0 })
    }

    // MARK: Shopping list

    func testShoppingListMutationsPersist() {
        let persistence = InMemoryPersistence()
        let store = makeStore(shoppingList: [], persistence: persistence)

        store.addToShoppingList(name: "Bananas", note: "ripe")
        XCTAssertEqual(store.shoppingList.map(\.name), ["Bananas"])
        XCTAssertEqual(store.shoppingList.first?.note, "ripe")
        XCTAssertEqual(persistence.loadShoppingList()?.count, 1)

        store.toggleShoppingItem(store.shoppingList[0])
        XCTAssertTrue(store.shoppingList[0].isChecked)
        XCTAssertEqual(persistence.loadShoppingList()?.first?.isChecked, true)

        store.removeShoppingItem(store.shoppingList[0])
        XCTAssertTrue(store.shoppingList.isEmpty)
        XCTAssertEqual(persistence.loadShoppingList()?.isEmpty, true)
    }
}
