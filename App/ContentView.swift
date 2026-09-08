import SwiftUI

// MARK: - Content View (Main Tab Navigation)

/// Root view: owns the shared ``FoodStore``, hosts the Home/Scan/Kitchen tabs, and
/// presents the scanner. Acts as the composition root that injects the store downward.
struct ContentView: View {
    @StateObject private var store: FoodStore
    @State private var selectedTab: Tab = .home

    /// - Parameter store: The shared store. Defaults to a file-backed store, but
    ///   UI tests launched with `-uitest-reset` get a fresh in-memory store so
    ///   every run starts from clean sample data and never touches disk.
    init(store: FoodStore? = nil) {
        let resolved: FoodStore
        if let store {
            resolved = store
        } else if ProcessInfo.processInfo.arguments.contains("-uitest-reset") {
            resolved = FoodStore(persistence: InMemoryPersistence())
        } else {
            resolved = FoodStore()
        }
        _store = StateObject(wrappedValue: resolved)
    }
    @State private var showScanner = false
    @State private var showAddItem = false
    @State private var showNotifications = false

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
        .sheet(isPresented: $showNotifications) {
            NotificationsSheet(store: store)
        }
        .task {
            await store.notificationManager.requestAuthorization()
        }
    }

    // MARK: - Top App Bar (Glassmorphism per design)

    private var topAppBar: some View {
        HStack {
            HStack(spacing: 12) {
                // App leaf mark
                Circle()
                    .fill(Color.ftSurfaceContainerHigh)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.ftPrimary)
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
            Button { showNotifications = true } label: {
                Image(systemName: "bell")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.ftPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.ftSurfaceContainerLowest)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                    .overlay(alignment: .topTrailing) {
                        if !store.itemsNeedingAttention.isEmpty {
                            Text("\(store.itemsNeedingAttention.count)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.ftOnError)
                                .padding(.horizontal, 5)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Color.ftError, in: Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
            }
            .accessibilityLabel("Notifications")
            .accessibilityIdentifier("home.notifications")
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

// MARK: - Notifications Sheet

/// The bell's panel: the items expiring soon (or already expired) that the app
/// alerts about, plus a section reflecting and managing notification permission.
struct NotificationsSheet: View {
    @ObservedObject var store: FoodStore
    @ObservedObject var notificationManager: NotificationManager
    @Environment(\.dismiss) private var dismiss
    /// The item being edited, driving the edit sheet.
    @State private var editingItem: FoodItem?

    init(store: FoodStore) {
        self.store = store
        self.notificationManager = store.notificationManager
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FTSpacing.xl) {
                    alertsSection
                    permissionSection
                }
                .padding(FTSpacing.xl)
            }
            .background(Color.ftSurface)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.ftPrimary)
                }
            }
            .sheet(item: $editingItem) { item in
                EditItemSheet(item: item, store: store)
            }
            .task { await notificationManager.refreshAuthorizationStatus() }
        }
    }

    // MARK: Expiring-soon alerts

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.lg) {
            Text("Expiring Soon")
                .font(FTFonts.headlineMedium)
                .foregroundStyle(Color.ftOnSurface)

            let items = store.itemsNeedingAttention
            if items.isEmpty {
                emptyState
            } else {
                ForEach(items) { item in
                    FoodItemCard(item: item)
                        .onTapGesture { editingItem = item }
                }
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.ftPrimaryFixed)
                Text("Nothing expiring soon")
                    .font(FTFonts.bodyMediumFont)
                    .foregroundStyle(Color.ftOnSurfaceVariant)
            }
            .padding(.vertical, FTSpacing.xl)
            Spacer()
        }
    }

    // MARK: Permission

    @ViewBuilder
    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("Alerts")
                .font(FTFonts.headlineSmall)
                .foregroundStyle(Color.ftOnSurface)

            switch notificationManager.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                permissionRow(
                    icon: "checkmark.circle.fill",
                    color: .ftPrimary,
                    text: "Notifications are on. We'll remind you two days before an item expires."
                )
            case .denied:
                VStack(alignment: .leading, spacing: FTSpacing.md) {
                    permissionRow(
                        icon: "bell.slash.fill",
                        color: .ftError,
                        text: "Notifications are off. Turn them on in Settings to get expiry reminders."
                    )
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(FTPrimaryButtonStyle())
                }
            default:
                VStack(alignment: .leading, spacing: FTSpacing.md) {
                    permissionRow(
                        icon: "bell.badge.fill",
                        color: .ftTertiary,
                        text: "Enable notifications to get a reminder two days before an item expires."
                    )
                    Button("Turn On Notifications") {
                        Task { await notificationManager.requestAuthorization() }
                    }
                    .buttonStyle(FTPrimaryButtonStyle())
                }
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ftSurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
    }

    private func permissionRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: FTSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(text)
                .font(FTFonts.bodyMediumFont)
                .foregroundStyle(Color.ftOnSurfaceVariant)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    ContentView()
}
