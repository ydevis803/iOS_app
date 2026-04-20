import SwiftUI

// MARK: - FoodStore (Central State Manager)

@MainActor
final class FoodStore: ObservableObject {
    @Published var items: [FoodItem] = FoodItem.sampleItems
    @Published var shoppingList: [ShoppingItem] = ShoppingItem.sampleItems
    @Published var recipes: [Recipe] = Recipe.sampleRecipes

    let calendarManager = CalendarManager()
    let notificationManager = NotificationManager()

    // MARK: - Pantry Operations

    func addItem(_ item: FoodItem) async {
        var newItem = item

        // Schedule notification 2 days before expiry
        await notificationManager.requestAuthorization()
        newItem.notificationID = notificationManager.scheduleExpiryAlert(for: newItem)

        // Add to calendar
        newItem.calendarEventID = await calendarManager.addExpirationEvent(for: newItem)

        items.append(newItem)
    }

    func removeItem(_ item: FoodItem) {
        if let notifID = item.notificationID {
            notificationManager.cancelNotification(identifier: notifID)
        }
        if let eventID = item.calendarEventID {
            calendarManager.removeEvent(identifier: eventID)
        }
        items.removeAll { $0.id == item.id }
    }

    func addToShoppingList(name: String, note: String = "") {
        shoppingList.append(ShoppingItem(name: name, note: note))
    }

    func toggleShoppingItem(_ item: ShoppingItem) {
        guard let index = shoppingList.firstIndex(where: { $0.id == item.id }) else { return }
        shoppingList[index].isChecked.toggle()
    }

    func removeShoppingItem(_ item: ShoppingItem) {
        shoppingList.removeAll { $0.id == item.id }
    }

    // MARK: - Computed

    var expiringSoonItems: [FoodItem] {
        items.filter { $0.daysUntilExpiry <= 4 && $0.daysUntilExpiry >= 0 }
            .sorted { $0.daysUntilExpiry < $1.daysUntilExpiry }
    }

    var sortedItems: [FoodItem] {
        items.sorted { $0.daysUntilExpiry < $1.daysUntilExpiry }
    }

    /// Items expiring on a specific date
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
