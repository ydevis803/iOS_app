import Foundation
@testable import FreshTrack

/// Shared fixtures for the unit-test target.
enum Fixtures {
    /// A minimal item whose expiry is `days` whole days from today.
    static func item(
        _ name: String,
        days: Int,
        placement: StoragePlacement = .fridge,
        category: FoodCategory = .other
    ) -> FoodItem {
        FoodItem(
            name: name,
            expirationDate: Calendar.current.date(byAdding: .day, value: days, to: Date())!,
            placement: placement,
            category: category
        )
    }
}
