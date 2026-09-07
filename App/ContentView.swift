import SwiftUI

// MARK: - Content View (Main Tab Navigation)

/// Root view: owns the shared ``FoodStore``, hosts the Home/Scan/Kitchen tabs, and
/// presents the scanner. Acts as the composition root that injects the store downward.
struct ContentView: View {
    @StateObject private var store = FoodStore()
    @State private var selectedTab: Tab = .home
    @State private var showScanner = false
    @State private var showAddItem = false

    enum Tab: String, CaseIterable {
        case home = "Home"
        case scan = "Scan"
        case kitchen = "Kitchen"

        var icon: String {
            switch self {
            case .home: return "house"
            case .scan: return "viewfinder"
            case .kitchen: return "fork.knife"
            }
        }

        var filledIcon: String {
            switch self {
            case .home: return "house.fill"
            case .scan: return "viewfinder"
            case .kitchen: return "fork.knife"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.ftSurface.ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // Top App Bar
                topAppBar

                // Active Tab View
                Group {
                    switch selectedTab {
                    case .home:
                        HomeView(
                            store: store,
                            onScan: { showScanner = true },
                            onAddManual: { showAddItem = true },
                            onShopping: {
                                withAnimation(.spring(response: 0.3)) {
                                    kitchenSection = .recipes
                                    selectedTab = .kitchen
                                }
                            }
                        )
                    case .scan:
                        Color.clear.onAppear {
                            showScanner = true
                            selectedTab = .home
                        }
                    case .kitchen:
                        kitchenTabView
                    }
                }
                .frame(maxHeight: .infinity)
            }

            // Bottom Navigation Bar
            bottomNavBar
        }
        // Let the bottom-aligned nav bar run through the home-indicator area;
        // otherwise scrolled content shows in a strip beneath it and can catch
        // taps there. The bar's own bottom padding covers the indicator.
        .ignoresSafeArea(.container, edges: .bottom)
        .fullScreenCover(isPresented: $showScanner) {
            ScannerView(
                onItemScanned: { result in handleScanResult(result) },
                onAddManual: {
                    // The cover is dismissing; present the sheet once it is gone.
                    showScanner = false
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        showAddItem = true
                    }
                }
            )
        }
        .sheet(isPresented: $showAddItem) {
            AddItemSheet(store: store)
        }
        .task {
            await store.notificationManager.requestAuthorization()
        }
    }

    // MARK: - Top App Bar (Glassmorphism per design)

    private var topAppBar: some View {
        HStack {
            HStack(spacing: 12) {
                // Profile avatar placeholder
                Circle()
                    .fill(Color.ftSurfaceContainerHigh)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.ftPrimaryContainer)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.ftPrimaryContainer, lineWidth: 2)
                    )

                // Logo text — Manrope, black, italic per HTML
                Text("FreshTrack")
                    .font(.system(size: 28, weight: .black, design: .default))
                    .italic()
                    .foregroundStyle(Color.ftPrimary)
            }

            Spacer()

            // Notifications button
            Button {} label: {
                Image(systemName: "bell")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.ftPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.ftSurfaceContainerLowest)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            }
        }
        .padding(.horizontal, FTSpacing.xl)
        .padding(.top, 8)
        .padding(.bottom, FTSpacing.lg)
        .background(.ultraThinMaterial)
    }

    // MARK: - Kitchen Tab with sub-sections

    @State private var kitchenSection: KitchenSection = .pantry

    enum KitchenSection: String, CaseIterable {
        case pantry = "Pantry"
        case recipes = "Recipes"
    }

    private var kitchenTabView: some View {
        VStack(spacing: 0) {
            // Sub-tab selector
            HStack(spacing: 0) {
                ForEach(KitchenSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            kitchenSection = section
                        }
                    } label: {
                        Text(section.rawValue)
                            .font(FTFonts.bodySemiBold(13))
                            .foregroundStyle(
                                kitchenSection == section
                                    ? Color.ftPrimary
                                    : Color.ftOnSurfaceVariant
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                kitchenSection == section
                                    ? Color.ftSurfaceContainerLowest
                                    : Color.clear
                            )
                            .clipShape(Capsule())
                            .shadow(
                                color: kitchenSection == section ? .black.opacity(0.04) : .clear,
                                radius: 4, y: 2
                            )
                    }
                }
            }
            .padding(3)
            .background(Color.ftSurfaceContainerLow)
            .clipShape(Capsule())
            .padding(.horizontal, FTSpacing.lg)
            .padding(.vertical, FTSpacing.sm)

            switch kitchenSection {
            case .pantry:
                PantryView(
                    store: store,
                    onScan: { showScanner = true },
                    onAddManual: { showAddItem = true }
                )
            case .recipes:
                RecipesView(store: store)
            }
        }
    }

    // MARK: - Bottom Navigation Bar

    private var bottomNavBar: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    if tab == .scan {
                        showScanner = true
                    } else {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == tab ? tab.filledIcon : tab.icon)
                            .font(.system(size: 22))
                        Text(tab.rawValue.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1)
                    }
                    .foregroundStyle(
                        selectedTab == tab
                            ? Color.ftOnPrimaryFixed
                            : Color.ftNavInactive
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == tab
                            ? Color.ftSecondaryContainer
                            : Color.clear
                    )
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, FTSpacing.lg)
        .padding(.top, FTSpacing.lg)
        .padding(.bottom, 36) // Safe area + spacing
        .ftGlassNav()
    }

    // MARK: - Handle Scan

    private func handleScanResult(_ result: ScanResult) {
        Task { await store.addScanned(result) }
    }
}

#Preview {
    ContentView()
}
