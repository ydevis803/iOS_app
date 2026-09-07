import SwiftUI
import Combine

// MARK: - Pantry View Model

/// Supplies the sorted inventory and its mutations to the pantry list.
@MainActor
final class PantryViewModel: ObservableObject {
    private let store: FoodStore
    private var cancellables = Set<AnyCancellable>()

    init(store: FoodStore) {
        self.store = store
        store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var items: [FoodItem] { store.sortedItems }

    func remove(_ item: FoodItem) { store.removeItem(item) }

    func addScanned(_ result: ScanResult) async { await store.addScanned(result) }
}

// MARK: - Pantry View (Inventory / Calendar Toggle)

/// Inventory screen with a list/calendar toggle and entry points for scanning or
/// manually adding items.
struct PantryView: View {
    @StateObject private var viewModel: PantryViewModel
    private let store: FoodStore
    @State private var viewMode: ViewMode = .list
    @State private var showScanner = false
    @State private var showAddItem = false

    init(store: FoodStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: PantryViewModel(store: store))
    }

    enum ViewMode: String, CaseIterable {
        case list = "List View"
        case calendar = "Calendar View"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.ftSurface.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: FTSpacing.xl) {
                    // Page header
                    Text("My Pantry")
                        .font(FTFonts.displayMedium)
                        .foregroundStyle(Color.ftOnSurface)
                        .tracking(-0.5)

                    // Segmented toggle
                    segmentedToggle

                    // Content
                    switch viewMode {
                    case .list:
                        listView
                    case .calendar:
                        CalendarGridView(store: store)
                    }

                    // Add button
                    addButton
                        .padding(.top, FTSpacing.lg)
                }
                .padding(.horizontal, FTSpacing.lg)
                .padding(.top, FTSpacing.lg)
                .padding(.bottom, 120)
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            ScannerView { result in
                handleScanResult(result)
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddItemSheet(store: store)
        }
    }

    // MARK: - Segmented Toggle

    private var segmentedToggle: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(FTFonts.bodySemiBold(14))
                        .foregroundStyle(viewMode == mode ? Color.ftPrimary : Color.ftOnSurface)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            viewMode == mode
                                ? Color.ftSurfaceContainerLowest
                                : Color.clear
                        )
                        .clipShape(Capsule())
                        .shadow(
                            color: viewMode == mode ? Color.black.opacity(0.04) : .clear,
                            radius: 4,
                            y: 2
                        )
                }
            }
        }
        .padding(4)
        .background(Color.ftSurfaceContainerLow)
        .clipShape(Capsule())
    }

    // MARK: - List View

    private var listView: some View {
        LazyVStack(spacing: FTSpacing.lg) {
            ForEach(viewModel.items) { item in
                FoodItemCard(item: item)
                    // `.swipeActions` only works inside a `List`; this layout is a
                    // `LazyVStack`, so a context menu provides the delete affordance.
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation { viewModel.remove(item) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    // MARK: - Add Button

    private var addButton: some View {
        VStack(spacing: FTSpacing.sm) {
            Button {
                showScanner = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Log New Ingredients")
                }
            }
            .buttonStyle(FTPrimaryButtonStyle())
            .frame(maxWidth: 280)

            // Secondary path for items without a barcode (or without a camera).
            Button {
                showAddItem = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14))
                    Text("Add Manually")
                        .font(FTFonts.bodySemiBold(14))
                }
                .foregroundStyle(Color.ftPrimary)
                .padding(FTSpacing.sm)
            }
            .accessibilityLabel("Add Manually")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Handle Scan

    private func handleScanResult(_ result: ScanResult) {
        Task { await viewModel.addScanned(result) }
    }
}

// MARK: - Add Item View Model

/// Owns the manual-entry form state and persistence for ``AddItemSheet``.
@MainActor
final class AddItemViewModel: ObservableObject {
    @Published var name = ""
    @Published var brand = ""
    @Published var quantity = ""
    @Published var expirationDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    @Published var placement: StoragePlacement = .fridge
    @Published var category: FoodCategory = .other

    private let store: FoodStore

    init(store: FoodStore) {
        self.store = store
    }

    var canSave: Bool { !name.isEmpty }

    /// Persists the entered item (which also schedules its alert + calendar event).
    func save() async {
        let item = FoodItem(
            name: name,
            brand: brand,
            quantity: quantity,
            expirationDate: expirationDate,
            placement: placement,
            category: category
        )
        await store.addItem(item)
    }
}

// MARK: - Add Item Sheet (Manual Entry)

/// Modal form for manually entering a new pantry item.
struct AddItemSheet: View {
    @StateObject private var viewModel: AddItemViewModel
    @Environment(\.dismiss) private var dismiss

    init(store: FoodStore) {
        _viewModel = StateObject(wrappedValue: AddItemViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    formField(label: "ITEM NAME", text: $viewModel.name, placeholder: "e.g. Baby Spinach")
                    formField(label: "BRAND", text: $viewModel.brand, placeholder: "e.g. Organic Valley")
                    formField(label: "QUANTITY", text: $viewModel.quantity, placeholder: "e.g. 6 oz")

                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text("EXPIRATION DATE")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.ftOnSurfaceVariant)
                        DatePicker("", selection: $viewModel.expirationDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(Color.ftPrimary)
                    }

                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text("PLACEMENT")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.ftOnSurfaceVariant)
                        // Six placements do not fit a segmented control on iPhone widths
                        // (labels truncate to "Count…"), so use a menu like Category.
                        Picker("Placement", selection: $viewModel.placement) {
                            ForEach(StoragePlacement.allCases, id: \.self) { p in
                                Text(p.label).tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.ftPrimary)
                    }

                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text("CATEGORY")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.ftOnSurfaceVariant)
                        Picker("Category", selection: $viewModel.category) {
                            ForEach(FoodCategory.allCases, id: \.self) { c in
                                Text(c.rawValue).tag(c)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.ftPrimary)
                    }

                    Button {
                        Task {
                            await viewModel.save()
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.plus")
                            Text("Add & Set 2-Day Alert")
                        }
                    }
                    .buttonStyle(FTPrimaryButtonStyle())
                    .disabled(!viewModel.canSave)
                    .opacity(viewModel.canSave ? 1 : 0.5)
                    .padding(.top, FTSpacing.lg)
                }
                .padding(FTSpacing.xl)
            }
            .background(Color.ftSurface)
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.ftPrimary)
                }
            }
        }
    }

    private func formField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color.ftOnSurfaceVariant)
            TextField(placeholder, text: text)
                .font(FTFonts.bodyLarge)
                .padding(FTSpacing.lg)
                .background(Color.ftSurfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
        }
    }
}

#Preview {
    PantryView(store: FoodStore())
}
