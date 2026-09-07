import Foundation

/// Typical shelf life per food category, used when a package carries no printed
/// date. Estimates are deliberately conservative and the resulting item is tagged
/// as estimated so the reminder is understood as a best guess.
enum ShelfLifeEstimator {
    /// Days until an item of this category typically expires.
    static func days(for category: FoodCategory) -> Int {
        switch category {
        case .produce: return 5
        case .dairy: return 7
        case .meat: return 2
        case .bakery: return 3
        case .beverage: return 14
        case .frozen: return 90
        case .grain: return 180
        case .condiment: return 90
        case .snack: return 30
        case .other: return 7
        }
    }

    /// Human-readable subject for the estimate ("Typical shelf life for fresh produce").
    static func subject(for category: FoodCategory) -> String {
        switch category {
        case .produce: return "fresh produce"
        case .dairy: return "dairy"
        case .meat: return "fresh meat"
        case .bakery: return "baked goods"
        case .beverage: return "opened beverages"
        case .frozen: return "frozen food"
        case .grain: return "dry grains"
        case .condiment: return "opened condiments"
        case .snack: return "snacks"
        case .other: return "packaged food"
        }
    }

    /// The estimated expiry date for `category`, counted from `date`.
    static func estimatedExpiry(
        for category: FoodCategory,
        from date: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        calendar.date(byAdding: .day, value: days(for: category), to: date) ?? date
    }
}
