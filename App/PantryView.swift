import SwiftUI

// MARK: - Pantry View (Inventory / Calendar Toggle)

struct PantryView: View {
    @EnvironmentObject var store: FoodStore
    @State private var viewMode: ViewMode = .list
    @State private var showScanner = false
    @State private var showAddItem = false

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
                        CalendarGridView()
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
            AddItemSheet()
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
            ForEach(store.sortedItems) { item in
                FoodItemCard(item: item)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation { store.removeItem(item) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    // MARK: - Add Button

    private var addButton: some View {
        HStack {
            Spacer()
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
            Spacer()
        }
    }

    // MARK: - Handle Scan

    private func handleScanResult(_ result: ScanResult) {
        let item = FoodItem(
            name: result.productName ?? "Scanned Item",
            expirationDate: result.expirationDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            barcode: result.barcode
        )
        Task {
            await store.addItem(item)
        }
    }
}

// MARK: - Add Item Sheet (Manual Entry)

struct AddItemSheet: View {
    @EnvironmentObject var store: FoodStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var quantity = ""
    @State private var expirationDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    @State private var placement: StoragePlacement = .fridge
    @State private var category: FoodCategory = .other

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    formField(label: "ITEM NAME", text: $name, placeholder: "e.g. Baby Spinach")
                    formField(label: "BRAND", text: $brand, placeholder: "e.g. Organic Valley")
                    formField(label: "QUANTITY", text: $quantity, placeholder: "e.g. 6 oz")

                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text("EXPIRATION DATE")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.ftOnSurfaceVariant)
                        DatePicker("", selection: $expirationDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(Color.ftPrimary)
                    }

                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text("PLACEMENT")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.ftOnSurfaceVariant)
                        Picker("Placement", selection: $placement) {
                            ForEach(StoragePlacement.allCases, id: \.self) { p in
                                Text(p.label).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text("CATEGORY")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.ftOnSurfaceVariant)
                        Picker("Category", selection: $category) {
                            ForEach(FoodCategory.allCases, id: \.self) { c in
                                Text(c.rawValue).tag(c)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.ftPrimary)
                    }

                    Button {
                        let item = FoodItem(
                            name: name,
                            brand: brand,
                            quantity: quantity,
                            expirationDate: expirationDate,
                            placement: placement,
                            category: category
                        )
                        Task {
                            await store.addItem(item)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.plus")
                            Text("Add & Set 2-Day Alert")
                        }
                    }
                    .buttonStyle(FTPrimaryButtonStyle())
                    .disabled(name.isEmpty)
                    .opacity(name.isEmpty ? 0.5 : 1)
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
    PantryView()
        .environmentObject(FoodStore())
}
