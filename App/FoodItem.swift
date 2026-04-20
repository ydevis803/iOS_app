import Foundation
import SwiftUI

// MARK: - Food Item Data Model

struct FoodItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var brand: String
    var quantity: String
    var expirationDate: Date
    var placement: StoragePlacement
    var category: FoodCategory
    var barcode: String?
    var dateAdded: Date
    var calendarEventID: String?
    var notificationID: String?

    init(
        id: UUID = UUID(),
        name: String,
        brand: String = "",
        quantity: String = "",
        expirationDate: Date,
        placement: StoragePlacement = .fridge,
        category: FoodCategory = .other,
        barcode: String? = nil,
        dateAdded: Date = Date(),
        calendarEventID: String? = nil,
        notificationID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.quantity = quantity
        self.expirationDate = expirationDate
        self.placement = placement
        self.category = category
        self.barcode = barcode
        self.dateAdded = dateAdded
        self.calendarEventID = calendarEventID
        self.notificationID = notificationID
    }

    // MARK: - Computed Properties

    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: expirationDate)).day ?? 0
    }

    var freshnessStatus: FreshnessStatus {
        switch daysUntilExpiry {
        case ..<0: return .expired
        case 0...1: return .critical
        case 2...4: return .warning
        default: return .safe
        }
    }

    var expiryLabel: String {
        let days = daysUntilExpiry
        switch days {
        case ..<0: return "Expired \(abs(days))d ago"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "\(days) Days"
        }
    }

    var placementLabel: String {
        placement.label
    }
}

// MARK: - Storage Placement

enum StoragePlacement: String, Codable, CaseIterable, Hashable {
    case fridge = "Fridge"
    case freezer = "Freezer"
    case pantry = "Pantry"
    case countertop = "Countertop"
    case fridgeDoor = "Fridge Door"
    case bottomDrawer = "Bottom Drawer"

    var label: String { rawValue }

    var icon: String {
        switch self {
        case .fridge, .fridgeDoor, .bottomDrawer: return "refrigerator"
        case .freezer: return "snowflake"
        case .pantry: return "cabinet"
        case .countertop: return "table.furniture"
        }
    }
}

// MARK: - Food Category

enum FoodCategory: String, Codable, CaseIterable, Hashable {
    case dairy = "Dairy"
    case produce = "Produce"
    case meat = "Meat"
    case bakery = "Bakery"
    case beverage = "Beverage"
    case frozen = "Frozen"
    case grain = "Grain"
    case condiment = "Condiment"
    case snack = "Snack"
    case other = "Other"

    var icon: String {
        switch self {
        case .dairy: return "cup.and.saucer"
        case .produce: return "leaf"
        case .meat: return "fork.knife"
        case .bakery: return "birthday.cake"
        case .beverage: return "mug"
        case .frozen: return "snowflake"
        case .grain: return "sparkles"
        case .condiment: return "drop"
        case .snack: return "popcorn"
        case .other: return "bag"
        }
    }
}

// MARK: - Recipe Model (for Batch Cooking)

struct Recipe: Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let portions: Int
    let ingredients: [String]
    let urgencyLevel: RecipeUrgency

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        portions: Int,
        ingredients: [String],
        urgencyLevel: RecipeUrgency = .smartIdea
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.portions = portions
        self.ingredients = ingredients
        self.urgencyLevel = urgencyLevel
    }
}

enum RecipeUrgency: String, Hashable {
    case urgentPrep = "URGENT PREP"
    case smartIdea = "SMART IDEA"

    var color: Color {
        switch self {
        case .urgentPrep: return .ftError
        case .smartIdea: return .ftTertiary
        }
    }

    var icon: String {
        switch self {
        case .urgentPrep: return "exclamationmark.triangle"
        case .smartIdea: return "brain.head.profile"
        }
    }
}

// MARK: - Shopping List Item

struct ShoppingItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var isChecked: Bool
    var note: String

    init(id: UUID = UUID(), name: String, isChecked: Bool = false, note: String = "") {
        self.id = id
        self.name = name
        self.isChecked = isChecked
        self.note = note
    }
}

// MARK: - Scan Result

struct ScanResult {
    var productName: String?
    var expirationDate: Date?
    var barcode: String?
}

// MARK: - Sample Data

extension FoodItem {
    static let sampleItems: [FoodItem] = [
        FoodItem(
            name: "Baby Spinach",
            brand: "Organic Valley",
            quantity: "6 oz",
            expirationDate: Calendar.current.date(byAdding: .day, value: 0, to: Date())!,
            placement: .bottomDrawer,
            category: .produce
        ),
        FoodItem(
            name: "Hass Avocados",
            brand: "",
            quantity: "3 count",
            expirationDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
            placement: .countertop,
            category: .produce
        ),
        FoodItem(
            name: "Almond Milk",
            brand: "Nature's Best",
            quantity: "1L",
            expirationDate: Calendar.current.date(byAdding: .day, value: 8, to: Date())!,
            placement: .fridgeDoor,
            category: .beverage
        ),
        FoodItem(
            name: "Beef Chuck",
            brand: "Butcher's Choice",
            quantity: "2 lbs",
            expirationDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
            placement: .fridge,
            category: .meat
        ),
        FoodItem(
            name: "Carrots",
            brand: "",
            quantity: "1 bag",
            expirationDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
            placement: .bottomDrawer,
            category: .produce
        ),
        FoodItem(
            name: "Onions",
            brand: "",
            quantity: "3 count",
            expirationDate: Calendar.current.date(byAdding: .day, value: 4, to: Date())!,
            placement: .pantry,
            category: .produce
        ),
        FoodItem(
            name: "Tomatoes",
            brand: "",
            quantity: "4 count",
            expirationDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
            placement: .countertop,
            category: .produce
        ),
        FoodItem(
            name: "Celery",
            brand: "",
            quantity: "1 bunch",
            expirationDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!,
            placement: .fridge,
            category: .produce
        ),
        FoodItem(
            name: "Greek Yogurt",
            brand: "Fage",
            quantity: "500g",
            expirationDate: Calendar.current.date(byAdding: .day, value: 6, to: Date())!,
            placement: .fridge,
            category: .dairy
        ),
        FoodItem(
            name: "Sourdough Bread",
            brand: "Local Bakery",
            quantity: "1 loaf",
            expirationDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            placement: .countertop,
            category: .bakery
        )
    ]
}

extension Recipe {
    static let sampleRecipes: [Recipe] = [
        Recipe(
            name: "Classic Pot Roast",
            description: "Your beef, carrots, and onions are expiring in 2 days. Slow cook them today for meals all week.",
            portions: 6,
            ingredients: ["Beef Chuck", "Carrots", "Onions"],
            urgencyLevel: .urgentPrep
        ),
        Recipe(
            name: "Vegetable Minestrone",
            description: "Use up those softening tomatoes, celery, and spinach before they turn.",
            portions: 4,
            ingredients: ["Tomatoes", "Celery", "Baby Spinach"],
            urgencyLevel: .smartIdea
        ),
        Recipe(
            name: "Avocado Toast Brunch",
            description: "Perfect way to use ripe avocados and sourdough before they go.",
            portions: 4,
            ingredients: ["Hass Avocados", "Sourdough Bread", "Tomatoes"],
            urgencyLevel: .urgentPrep
        ),
        Recipe(
            name: "Yogurt Smoothie Bowl",
            description: "Blend yogurt with spinach and top with fresh ingredients.",
            portions: 2,
            ingredients: ["Greek Yogurt", "Baby Spinach", "Almond Milk"],
            urgencyLevel: .smartIdea
        ),
        Recipe(
            name: "Stir-Fried Vegetables",
            description: "Quick stir-fry with carrots, celery, and onions.",
            portions: 3,
            ingredients: ["Carrots", "Celery", "Onions"],
            urgencyLevel: .smartIdea
        )
    ]
}

extension ShoppingItem {
    static let sampleItems: [ShoppingItem] = [
        ShoppingItem(name: "Whole Milk", note: "Expired yesterday"),
        ShoppingItem(name: "Sourdough Bread", note: "Used up"),
        ShoppingItem(name: "Eggs (Dozen)", isChecked: true)
    ]
}
