import SwiftUI

// MARK: - Home View (Dashboard)

struct HomeView: View {
    @EnvironmentObject var store: FoodStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: FTSpacing.xl) {
                // Freshness summary
                freshnessSummary

                // Expiring soon section
                if !store.expiringSoonItems.isEmpty {
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

                    Text("\(freshnessScore)%")
                        .font(FTFonts.displayLarge)
                        .foregroundStyle(Color.ftPrimary)
                        .tracking(-1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: FTSpacing.xs) {
                    statPill(count: safeCount, label: "Fresh", color: .ftPrimaryFixed)
                    statPill(count: warningCount, label: "Warning", color: .ftTertiaryContainer)
                    statPill(count: criticalCount, label: "Critical", color: .ftErrorContainer)
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

    private var safeCount: Int { store.items.filter { $0.freshnessStatus == .safe }.count }
    private var warningCount: Int { store.items.filter { $0.freshnessStatus == .warning }.count }
    private var criticalCount: Int { store.items.filter { $0.freshnessStatus == .critical || $0.freshnessStatus == .expired }.count }
    private var freshnessScore: Int {
        guard !store.items.isEmpty else { return 100 }
        let fresh = store.items.filter { $0.freshnessStatus == .safe }.count
        return Int((Double(fresh) / Double(store.items.count)) * 100)
    }

    // MARK: - Expiring Soon

    private var expiringSoonSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.lg) {
            Text("Expiring Soon")
                .font(FTFonts.headlineMedium)
                .foregroundStyle(Color.ftOnSurface)

            ForEach(store.expiringSoonItems.prefix(5)) { item in
                FoodItemCard(item: item)
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
                quickActionCard(icon: "barcode.viewfinder", label: "Scan Item", color: .ftPrimary)
                quickActionCard(icon: "plus.circle", label: "Add Manual", color: .ftSecondary)
                quickActionCard(icon: "list.bullet", label: "Shopping", color: .ftTertiary)
            }
        }
    }

    private func quickActionCard(icon: String, label: String, color: Color) -> some View {
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
}

#Preview {
    HomeView()
        .environmentObject(FoodStore())
}
