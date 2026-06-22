import Foundation

// MARK: - Pantry Persistence

/// Abstraction over where pantry data is stored. Injecting this into ``FoodStore``
/// lets previews and tests use an in-memory double instead of the file system.
protocol PantryPersisting {
    /// Returns previously saved items, or `nil` if nothing has been persisted yet.
    func loadItems() -> [FoodItem]?
    /// Persists the current set of pantry items.
    func save(items: [FoodItem])
    /// Returns the previously saved shopping list, or `nil` if none exists.
    func loadShoppingList() -> [ShoppingItem]?
    /// Persists the current shopping list.
    func save(shoppingList: [ShoppingItem])
}

// MARK: - File-backed Persistence

/// Persists pantry data as JSON files in the app's Documents directory.
struct FilePersistence: PantryPersisting {
    private let itemsURL: URL
    private let shoppingURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Creates a file store. `directory` defaults to the user's Documents directory
    /// and is overridable so tests can write to a temporary location.
    init(directory: URL? = nil) {
        let base = directory
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        itemsURL = base.appendingPathComponent("freshtrack-items.json")
        shoppingURL = base.appendingPathComponent("freshtrack-shopping.json")
    }

    func loadItems() -> [FoodItem]? { load([FoodItem].self, from: itemsURL) }
    func save(items: [FoodItem]) { write(items, to: itemsURL) }
    func loadShoppingList() -> [ShoppingItem]? { load([ShoppingItem].self, from: shoppingURL) }
    func save(shoppingList: [ShoppingItem]) { write(shoppingList, to: shoppingURL) }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - In-memory Persistence

/// Non-persisting double for previews and tests; never touches disk.
final class InMemoryPersistence: PantryPersisting {
    private var items: [FoodItem]?
    private var shoppingList: [ShoppingItem]?

    init(items: [FoodItem]? = nil, shoppingList: [ShoppingItem]? = nil) {
        self.items = items
        self.shoppingList = shoppingList
    }

    func loadItems() -> [FoodItem]? { items }
    func save(items: [FoodItem]) { self.items = items }
    func loadShoppingList() -> [ShoppingItem]? { shoppingList }
    func save(shoppingList: [ShoppingItem]) { self.shoppingList = shoppingList }
}
