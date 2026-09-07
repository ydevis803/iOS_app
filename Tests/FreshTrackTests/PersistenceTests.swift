import XCTest
@testable import FreshTrack

final class FilePersistenceTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("freshtrack-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testLoadReturnsNilBeforeAnythingIsSaved() {
        let persistence = FilePersistence(directory: directory)
        XCTAssertNil(persistence.loadItems())
        XCTAssertNil(persistence.loadShoppingList())
    }

    func testItemsRoundTrip() {
        let persistence = FilePersistence(directory: directory)
        let items = [Fixtures.item("Milk", days: 2, category: .dairy), Fixtures.item("Rice", days: 40, placement: .pantry)]

        persistence.save(items: items)

        XCTAssertEqual(persistence.loadItems(), items)
        // A fresh instance pointing at the same directory sees the same data.
        XCTAssertEqual(FilePersistence(directory: directory).loadItems(), items)
    }

    func testShoppingListRoundTrip() {
        let persistence = FilePersistence(directory: directory)
        let list = [ShoppingItem(name: "Eggs", isChecked: true, note: "dozen")]

        persistence.save(shoppingList: list)

        XCTAssertEqual(persistence.loadShoppingList(), list)
    }

    func testCorruptFileIsTreatedAsNoData() throws {
        let persistence = FilePersistence(directory: directory)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("freshtrack-items.json"))
        XCTAssertNil(persistence.loadItems())
    }
}
