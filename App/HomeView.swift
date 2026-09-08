import SwiftUI
import Combine

// MARK: - Home View Model

/// Derives the dashboard's freshness statistics from the shared ``FoodStore``.
@MainActor
final class HomeViewModel: ObservableObject {
    private let store: FoodStore
    private var cancellables = Set<AnyCancellable>()

    init(store: FoodStore) {
        self.store = store
        // Re-publish store changes so the view refreshes when inventory mutates.
        store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var expiringSoonItems: [FoodItem] { store.expiringSoonItems }
    var hasExpiringSoon: Bool { !store.expiringSoonItems.isEmpty }

    var safeCount: Int { store.items.filter { $0.freshnessStatus == .safe }.count }
    var warningCount: Int { store.items.filter { $0.freshnessStatus == .warning }.count }
    var criticalCount: Int {
        store.items.filter { $0.freshnessStatus == .critical || $0.freshnessStatus == .expired }.count
    }

    /// Percentage of inventory that is still in the "safe" freshness band.
    var freshnessScore: Int {
        guard !store.items.isEmpty else { return 100 }
        let fresh = store.items.filter { $0.freshnessStatus == .safe }.count
        return Int((Double(fresh) / Double(store.items.count)) * 100)
    }
}

// MARK: - Home View (Dashboard)

/// Dashboard showing the overall freshness score, expiring-soon items, and quick actions.
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    private let store: FoodStore
    /// The item currently being edited, driving the edit sheet.
    @State private var editingItem: FoodItem?

    /// Quick-action handlers; navigation is owned by the parent, which injects them.
    private let onScan: () -> Void
    private let onAddManual: () -> Void
    private let onShopping: () -> Void

    init(
        store: FoodStore,
        onScan: @escaping () -> Void = {},
        onAddManual: @escaping () -> Void = {},
        onShopping: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(store: store))
        self.store = store
        self.onScan = onScan
        self.onAddManual = onAddManual
        self.onShopping = onShopping
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: FTSpacing.xl) {
                // Freshness summary
                freshnessSummary

                // Expiring soon section
                if viewModel.hasExpiringSoon {
                    expiringSoonSection
                }

                // Quick actions
                quickActionsRow
            }
            .padding(.horizontal, FTSpacing.lg)
            .padding(.top, FTSpacing.lg)
            .padding(.bottom, 120)
        }
        .background(Color.ftSurface)
        .sheet(item: $editingItem) { item in
            EditItemSheet(item: item, store: store)
        }
    }

    // MARK: - Freshness Summary

    private var freshnessSummary: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("Freshness Score")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Color.ftOnSurfaceVariant)

                    Text("\(viewModel.freshnessScore)%")
                        .font(FTFonts.displayLarge)
                        .foregroundStyle(Color.ftPrimary)
                        .tracking(-1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: FTSpacing.xs) {
                    statPill(count: viewModel.safeCount, label: "Fresh", color: .ftPrimaryFixed)
                    statPill(count: viewModel.warningCount, label: "Warning", color: .ftTertiaryContainer)
                    statPill(count: viewModel.criticalCount, label: "Critical", color: .ftErrorContainer)
                }
            }
        }
        .padding(FTSpacing.xl)
        .background(Color.ftSurfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.section, style: .continuous))
        .shadow(
            color: FTShadow.elevated.color,
            radius: FTShadow.elevated.radius,
            x: FTShadow.elevated.x,
            y: FTShadow.elevated.y
        )
    }

    private func statPill(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(count) \(label)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.ftOnSurfaceVariant)
        }
    }

    // MARK: - Expiring Soon

    private var expiringSoonSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.lg) {
            Text("Expiring Soon")
                .font(FTFonts.headlineMedium)
                .foregroundStyle(Color.ftOnSurface)

            ForEach(viewModel.expiringSoonItems.prefix(5)) { item in
                FoodItemCard(item: item)
                    .onTapGesture { editingItem = item }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsRow: some View {
        VStack(alignment: .leading, spacing: FTSpacing.lg) {
            Text("Quick Actions")
                .font(FTFonts.headlineMedium)
                .foregroundStyle(Color.ftOnSurface)

            HStack(spacing: FTSpacing.lg) {
                quickActionCard(icon: "barcode.viewfinder", label: "Scan Item", color: .ftPrimary, action: onScan)
                quickActionCard(icon: "plus.circle", label: "Add Manual", color: .ftSecondary, action: onAddManual)
                quickActionCard(icon: "list.bullet", label: "Shopping", color: .ftTertiary, action: onShopping)
            }
        }
    }

    private func quickActionCard(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: FTSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.ftOnSurfaceVariant)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FTSpacing.xl)
            .background(Color.ftSurfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.card, style: .continuous))
            .shadow(color: FTShadow.card.color, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    HomeView(store: FoodStore())
}
