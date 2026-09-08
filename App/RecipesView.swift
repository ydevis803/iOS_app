import SwiftUI
import Combine

// MARK: - Recipes View Model

/// Scores recipes against the expiring inventory and supplies per-ingredient display data.
@MainActor
final class RecipesViewModel: ObservableObject {
    private let store: FoodStore
    private var cancellables = Set<AnyCancellable>()

    init(store: FoodStore) {
        self.store = store
        store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var scoredRecipes: [(recipe: Recipe, matchingIngredients: [String], matchCount: Int)] {
        store.scoredRecipes
    }

    /// Display label and freshness status for an ingredient, looked up by name in the pantry.
    func ingredientInfo(name: String) -> (label: String, status: FreshnessStatus?) {
        let item = store.items.first { $0.name == name }
        let label = item.map { "\(name) (\($0.daysUntilExpiry) days)" } ?? name
        return (label, item?.freshnessStatus)
    }
}

// MARK: - Recipes View (Smart Kitchen Prep / Batch Cooking)

/// Batch-cooking screen: recipes scored by how many expiring ingredients they use,
/// with the shopping list embedded below.
struct RecipesView: View {
    @StateObject private var viewModel: RecipesViewModel
    private let store: FoodStore
    /// The recipe whose detail sheet is showing.
    @State private var startedRecipe: Recipe?

    init(store: FoodStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: RecipesViewModel(store: store))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: FTSpacing.xxxl) {
                batchCookingSection
                shoppingListSection
            }
            .padding(.horizontal, FTSpacing.lg)
            .padding(.top, FTSpacing.lg)
            .padding(.bottom, 120)
        }
        .background(Color.ftSurface)
        .sheet(item: $startedRecipe) { recipe in
            RecipeDetailSheet(recipe: recipe, store: store)
        }
    }

    // MARK: - Batch Cooking Section

    private var batchCookingSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xl) {
            // Section container per design: rounded-[2rem], surface-container-low
            VStack(alignment: .leading, spacing: FTSpacing.xl) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.ftPrimary)
                        .symbolRenderingMode(.hierarchical)
                    Text("Smart Kitchen Prep")
                        .font(FTFonts.headlineLarge)
                        .foregroundStyle(Color.ftOnSurface)
                        .tracking(-0.3)
                }

                Text("Combine expiring ingredients to maximize freshness and save time this week.")
                    .font(FTFonts.bodyLarge)
                    .foregroundStyle(Color.ftOnSurfaceVariant)

                // Recipe cards
                let scored = viewModel.scoredRecipes
                if scored.isEmpty {
                    emptyRecipesState
                } else {
                    ForEach(scored, id: \.recipe.id) { entry in
                        recipeCard(
                            recipe: entry.recipe,
                            matchingIngredients: entry.matchingIngredients,
                            matchCount: entry.matchCount
                        )
                    }
                }
            }
            .padding(FTSpacing.xl)
            .background {
                ZStack {
                    Color.ftSurfaceContainerLow
                    // Decorative gradient blob (top-right corner per design)
                    Circle()
                        .fill(Color.ftPrimaryContainer.opacity(0.15))
                        .frame(width: 256, height: 256)
                        .offset(x: 100, y: -100)
                        .blur(radius: 30)
                }
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.section, style: .continuous))
            }
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.section, style: .continuous))
        }
    }

    // MARK: - Recipe Card

    private func recipeCard(recipe: Recipe, matchingIngredients: [String], matchCount: Int) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.lg) {
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    // Urgency label
                    HStack(spacing: 4) {
                        Image(systemName: recipe.urgencyLevel.icon)
                            .font(.system(size: 12))
                        Text(recipe.urgencyLevel.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.5)
                    }
                    .foregroundStyle(recipe.urgencyLevel.color)

                    Text(recipe.name)
                        .font(FTFonts.headlineSmall)
                        .foregroundStyle(Color.ftOnSurface)
                }

                Spacer()

                Text("\(recipe.portions) Portions")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.ftOnPrimaryContainer)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.ftPrimaryContainer.opacity(0.2))
                    .clipShape(Capsule())
            }

            Text(recipe.description)
                .font(FTFonts.bodyMediumFont)
                .foregroundStyle(Color.ftOnSurfaceVariant)

            // Ingredient chips
            FlowLayout(spacing: 8) {
                ForEach(recipe.ingredients, id: \.self) { ingredient in
                    ingredientChip(
                        name: ingredient,
                        isMatching: matchingIngredients.contains(ingredient)
                    )
                }
            }

            // Start recipe button
            Button { startedRecipe = recipe } label: {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 14))
                    Text("Start Recipe")
                }
            }
            .buttonStyle(FTPrimaryButtonStyle())
        }
        .padding(FTSpacing.xl)
        .background(Color.ftSurfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.card, style: .continuous))
        .shadow(
            color: FTShadow.card.color,
            radius: FTShadow.card.radius,
            x: FTShadow.card.x,
            y: FTShadow.card.y
        )
    }

    private func ingredientChip(name: String, isMatching: Bool) -> some View {
        let info = viewModel.ingredientInfo(name: name)

        return HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 10))
            Text(info.label)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isMatching ? chipBackground(for: info.status) : Color.ftSurfaceContainerLow)
        .foregroundStyle(isMatching ? chipForeground(for: info.status) : Color.ftOnSurfaceVariant)
        .clipShape(Capsule())
    }

    private func chipBackground(for status: FreshnessStatus?) -> Color {
        switch status {
        case .critical, .expired: return .ftErrorContainer
        case .warning: return .ftTertiaryContainer
        default: return .ftSecondaryContainer
        }
    }

    private func chipForeground(for status: FreshnessStatus?) -> Color {
        switch status {
        case .critical, .expired: return .ftOnErrorContainer
        case .warning: return .ftOnTertiaryContainer
        default: return .ftOnSecondaryContainer
        }
    }

    private var emptyRecipesState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 40))
                .foregroundStyle(Color.ftOutlineVariant)
            Text("No batch cooking suggestions yet.")
                .font(FTFonts.bodyMediumFont)
                .foregroundStyle(Color.ftOnSurfaceVariant)
            Text("Add more items to your pantry to get smart recipe ideas.")
                .font(FTFonts.bodySmall)
                .foregroundStyle(Color.ftOutline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.xxxl)
    }

    // MARK: - Shopping List Section (Inline)

    private var shoppingListSection: some View {
        ShoppingListView(store: store)
    }
}

// MARK: - Flow Layout (for ingredient chips wrapping)

/// A simple `Layout` that arranges subviews left-to-right, wrapping to a new line
/// when the proposed width is exceeded. Used for the wrapping ingredient chips.
struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return (positions, CGSize(width: maxWidth, height: currentY + lineHeight))
    }
}

// MARK: - Recipe Detail Sheet

/// Shows a recipe's details and which of its ingredients are in the pantry, with a
/// "Mark as Cooked" action that uses up (removes) those matching pantry items.
struct RecipeDetailSheet: View {
    let recipe: Recipe
    @ObservedObject var store: FoodStore
    @Environment(\.dismiss) private var dismiss

    /// Pantry items whose name matches one of the recipe's ingredients.
    private var pantryMatches: [FoodItem] {
        store.items.filter { recipe.ingredients.contains($0.name) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FTSpacing.xl) {
                    header
                    Text(recipe.description)
                        .font(FTFonts.bodyLarge)
                        .foregroundStyle(Color.ftOnSurfaceVariant)
                    ingredientsSection
                }
                .padding(FTSpacing.xl)
            }
            .background(Color.ftSurface)
            .navigationTitle("Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.ftPrimary)
                }
            }
            .safeAreaInset(edge: .bottom) { markCookedBar }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack(spacing: 4) {
                Image(systemName: recipe.urgencyLevel.icon)
                    .font(.system(size: 12))
                Text(recipe.urgencyLevel.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
            }
            .foregroundStyle(recipe.urgencyLevel.color)

            Text(recipe.name)
                .font(FTFonts.displayMedium)
                .foregroundStyle(Color.ftOnSurface)

            Text("\(recipe.portions) portions")
                .font(FTFonts.bodyMediumFont)
                .foregroundStyle(Color.ftOnSurfaceVariant)
        }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("INGREDIENTS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color.ftOnSurfaceVariant)

            ForEach(recipe.ingredients, id: \.self) { ingredient in
                ingredientRow(ingredient)
            }
        }
    }

    private func ingredientRow(_ name: String) -> some View {
        let item = store.items.first { $0.name == name }
        return HStack(spacing: FTSpacing.md) {
            Image(systemName: item == nil ? "circle" : "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(item == nil ? Color.ftOutline : Color.ftPrimary)
            Text(name)
                .font(FTFonts.bodyLarge)
                .foregroundStyle(Color.ftOnSurface)
            Spacer(minLength: 0)
            if let item {
                Text(item.expiryLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(item.freshnessStatus.chipForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(item.freshnessStatus.chipBackground)
                    .clipShape(Capsule())
            } else {
                Text("Not in pantry")
                    .font(FTFonts.bodyMediumFont)
                    .foregroundStyle(Color.ftOnSurfaceVariant)
            }
        }
        .padding(FTSpacing.md)
        .background(Color.ftSurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.md, style: .continuous))
    }

    private var markCookedBar: some View {
        VStack(spacing: FTSpacing.sm) {
            Button {
                store.markCooked(recipe)
                dismiss()
            } label: {
                Label("Mark as Cooked", systemImage: "checkmark")
            }
            .buttonStyle(FTPrimaryButtonStyle())
            .disabled(pantryMatches.isEmpty)
            .opacity(pantryMatches.isEmpty ? 0.5 : 1)

            Text(pantryMatches.isEmpty
                 ? "None of these are in your pantry yet."
                 : "Uses up \(pantryMatches.count) item\(pantryMatches.count == 1 ? "" : "s") from your pantry.")
                .font(FTFonts.bodySmall)
                .foregroundStyle(Color.ftOnSurfaceVariant)
        }
        .padding(FTSpacing.xl)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    RecipesView(store: FoodStore())
}
