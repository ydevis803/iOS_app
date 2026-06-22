import SwiftUI

// MARK: - FoodStore (Central State Manager)

/// Central, observable source of truth for pantry inventory, the shopping list, and
/// recipe suggestions. Inventory and shopping mutations persist automatically.
@MainActor
final class FoodStore: ObservableObject {
    @Published var items: [FoodItem] {
        didSet { persistence.save(items: items) }
    }
    @Published var shoppingList: [ShoppingItem] {
        didSet { persistence.save(shoppingList: shoppingList) }
    }
    @Published var recipes: [Recipe]

    let calendarManager: CalendarManager
    let notificationManager: NotificationManager
    private let persistence: PantryPersisting

    /// Creates a store with injectable state and collaborators so previews and tests
    /// can substitute fixtures/mocks instead of relying on hard-coded singletons.
    init(
        items: [FoodItem] = FoodItem.sampleItems,
        shoppingList: [ShoppingItem] = ShoppingItem.sampleItems,
        recipes: [Recipe] = Recipe.sampleRecipes,
        calendarManager: CalendarManager? = nil,
        notificationManager: NotificationManager? = nil,
        persistence: PantryPersisting = FilePersistence()
    ) {
        self.persistence = persistence
        // Prefer previously saved data; fall back to the provided seed (sample) data on
        // first launch. Property observers don't fire during init, so this won't re-save.
        self.items = persistence.loadItems() ?? items
        self.shoppingList = persistence.loadShoppingList() ?? shoppingList
        self.recipes = recipes
        // Construct defaults in-body: these are @MainActor types and can't be
        // built in a default argument's nonisolated context.
        self.calendarManager = calendarManager ?? CalendarManager()
        self.notificationManager = notificationManager ?? NotificationManager()
    }

    // MARK: - Pantry Operations

    /// Adds an item to the pantry, scheduling its 2-day-before notification and
    /// calendar event and recording their identifiers for later cleanup.
    func addItem(_ item: FoodItem) async {
        var newItem = item

        // Schedule notification 2 days before expiry
        await notificationManager.requestAuthorization()
        newItem.notificationID = notificationManager.scheduleExpiryAlert(for: newItem)

        // Add to calendar
        newItem.calendarEventID = await calendarManager.addExpirationEvent(for: newItem)

        items.append(newItem)
    }

    /// Builds a `FoodItem` from a scan result (defaulting expiry to a week out) and stores it.
    /// Centralizes the conversion that the scanner and pantry entry points both need.
    func addScanned(_ result: ScanResult) async {
        let item = FoodItem(
            name: result.productName ?? "Scanned Item",
            expirationDate: result.expirationDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            barcode: result.barcode
        )
        await addItem(item)
    }

    /// Removes an item and cancels its associated notification and calendar event.
    func removeItem(_ item: FoodItem) {
        if let notifID = item.notificationID {
            notificationManager.cancelNotification(identifier: notifID)
        }
        if let eventID = item.calendarEventID {
            calendarManager.removeEvent(identifier: eventID)
        }
        items.removeAll { $0.id == item.id }
    }

    /// Appends a new entry to the shopping list.
    func addToShoppingList(name: String, note: String = "") {
        shoppingList.append(ShoppingItem(name: name, note: note))
    }

    /// Flips the checked state of the given shopping-list item.
    func toggleShoppingItem(_ item: ShoppingItem) {
        guard let index = shoppingList.firstIndex(where: { $0.id == item.id }) else { return }
        shoppingList[index].isChecked.toggle()
    }

    /// Removes the given item from the shopping list.
    func removeShoppingItem(_ item: ShoppingItem) {
        shoppingList.removeAll { $0.id == item.id }
    }

    // MARK: - Computed

    /// Items expiring within the next four days (and not already expired), soonest first.
    var expiringSoonItems: [FoodItem] {
        items.filter { $0.daysUntilExpiry <= 4 && $0.daysUntilExpiry >= 0 }
            .sorted { $0.daysUntilExpiry < $1.daysUntilExpiry }
    }

    /// All items ordered by how soon they expire.
    var sortedItems: [FoodItem] {
        items.sorted { $0.daysUntilExpiry < $1.daysUntilExpiry }
    }

    /// Items expiring on a specific calendar day.
    func items(expiringOn date: Date) -> [FoodItem] {
        let calendar = Calendar.current
        return items.filter { calendar.isDate($0.expirationDate, inSameDayAs: date) }
    }

    // MARK: - Batch Cooking Logic

    /// Filter recipes that use 3+ ingredients from the "expiring soon" list
    var batchCookingRecipes: [Recipe] {
        let expiringNames = Set(expiringSoonItems.map { $0.name })
        return recipes
            .map { recipe -> (recipe: Recipe, matchCount: Int) in
                let matches = recipe.ingredients.filter { expiringNames.contains($0) }.count
                return (recipe, matches)
            }
            .filter { $0.matchCount >= 3 }
            .sorted { $0.matchCount > $1.matchCount }
            .map { $0.recipe }
    }

    /// All recipes scored by how many expiring ingredients they use
    var scoredRecipes: [(recipe: Recipe, matchingIngredients: [String], matchCount: Int)] {
        let expiringNames = Set(expiringSoonItems.map { $0.name })
        return recipes
            .map { recipe in
                let matching = recipe.ingredients.filter { expiringNames.contains($0) }
                return (recipe, matching, matching.count)
            }
            .sorted { $0.matchCount > $1.matchCount }
    }
}
