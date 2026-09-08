import Combine
import SwiftUI
import UIKit

/// Resigns the first responder to dismiss the software keyboard.
@MainActor private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

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
}

// MARK: - Pantry View (Inventory / Calendar Toggle)

/// Inventory screen with a list/calendar toggle and entry points for scanning or
/// manually adding items. Presentation of the scanner and the add sheet is owned
/// by the root view (``ContentView``): a sheet presented from this nested view
/// never appeared on device, so the entry points are injected as handlers.
struct PantryView: View {
    @StateObject private var viewModel: PantryViewModel
    private let store: FoodStore
    private let onScan: () -> Void
    private let onAddManual: () -> Void
    @State private var viewMode: ViewMode = .list
    /// The item currently being edited, driving the edit sheet.
    @State private var editingItem: FoodItem?

    init(
        store: FoodStore,
        onScan: @escaping () -> Void = {},
        onAddManual: @escaping () -> Void = {}
    ) {
        self.store = store
        self.onScan = onScan
        self.onAddManual = onAddManual
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
        .sheet(item: $editingItem) { item in
            EditItemSheet(item: item, store: store)
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
                // `.swipeActions` only works inside a `List`; this layout is a
                // `LazyVStack`, so `SwipeToDeleteRow` reproduces the gesture.
                SwipeToDeleteRow(onDelete: { withAnimation { viewModel.remove(item) } }) {
                    FoodItemCard(item: item)
                        // Tap to edit; the swipe drag requires movement, so a plain
                        // tap won't trigger it.
                        .onTapGesture { editingItem = item }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }

    // MARK: - Add Button

    private var addButton: some View {
        VStack(spacing: FTSpacing.sm) {
            Button(action: onScan) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Log New Ingredients")
                }
            }
            .buttonStyle(FTPrimaryButtonStyle())
            .frame(maxWidth: 280)

            // Secondary path for items without a barcode (or without a camera).
            Button(action: onAddManual) {
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

}

// MARK: - Swipe To Delete

/// Wraps a card in a swipe-left-to-delete interaction. SwiftUI's `.swipeActions`
/// requires a `List`; the pantry uses a `LazyVStack`, so this reproduces the
/// gesture with a custom drag. Swiping left reveals a trailing Delete button that
/// can be tapped, and a long swipe removes the row outright. VoiceOver users get
/// the same action via an accessibility action.
struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    /// Committed resting offset: 0 when closed, `-revealWidth` when the button shows.
    @State private var offset: CGFloat = 0
    /// Live finger translation during an in-progress drag.
    @GestureState private var translation: CGFloat = 0

    /// How far the card slides to reveal the Delete button.
    private let revealWidth: CGFloat = 88
    /// Past this leftward distance the swipe deletes without a second tap.
    private let fullSwipeThreshold: CGFloat = 240

    /// Current horizontal displacement, clamped so the card never slides right past closed.
    private var slide: CGFloat { min(0, offset + translation) }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Red surface + trash sit behind the (opaque) card and only show as it
            // slides left; matching the card's radius keeps the corners flush.
            RoundedRectangle(cornerRadius: FTRadius.card, style: .continuous)
                .fill(Color.ftError)

            // Only render the button once the row is open, so closed rows don't each
            // leave a hidden "Delete" in the accessibility tree (which also confuses
            // UI tests). VoiceOver users get the accessibility action on the card.
            if slide < 0 {
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.ftOnError)
                        .frame(width: revealWidth)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete")
            }

            content()
                .offset(x: slide)
                .gesture(drag)
                .accessibilityAction(named: Text("Delete"), onDelete)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: offset)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 20)
            .updating($translation) { value, state, _ in
                // Only claim predominantly-horizontal drags so the list still scrolls.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let projected = offset + value.translation.width
                if projected < -fullSwipeThreshold {
                    onDelete()
                } else if projected < -revealWidth / 2 {
                    offset = -revealWidth
                } else {
                    offset = 0
                }
            }
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
    @FocusState private var nameFocused: Bool

    init(store: FoodStore) {
        _viewModel = StateObject(wrappedValue: AddItemViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    // Name field carries focus + submit handling so the return key
                    // (and the keyboard Done button) reliably dismisses the keyboard,
                    // keeping the save button below reachable.
                    VStack(alignment: .leading, spacing: FTSpacing.sm) {
                        Text("ITEM NAME")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.ftOnSurfaceVariant)
                        TextField("e.g. Baby Spinach", text: $viewModel.name)
                            .font(FTFonts.bodyLarge)
                            .foregroundStyle(Color.ftPrimary)
                            .tint(Color.ftPrimary)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onSubmit { nameFocused = false }
                            .padding(FTSpacing.lg)
                            .background(Color.ftSurfaceContainerLow)
                            .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
                    }
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
            // Dismiss the keyboard as soon as the form is scrolled, so the save
            // button below the fold becomes reachable.
            .scrollDismissesKeyboard(.immediately)
            .background(Color.ftSurface)
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.ftPrimary)
                }
                // A Done button dismisses the keyboard so the save button below the
                // fold (the form sits in a scroll view) is reachable.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
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
                .foregroundStyle(Color.ftPrimary)
                .tint(Color.ftPrimary)
                .padding(FTSpacing.lg)
                .background(Color.ftSurfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
        }
    }
}

// MARK: - Edit Item View Model

/// Owns the editable fields for an existing pantry item and persists the changes.
/// Only name, category (which drives the card icon), placement, and expiry are
/// editable; every other field on the item is preserved.
@MainActor
final class EditItemViewModel: ObservableObject {
    @Published var name: String
    @Published var category: FoodCategory
    @Published var placement: StoragePlacement
    @Published var expirationDate: Date

    private let store: FoodStore
    private let original: FoodItem

    init(item: FoodItem, store: FoodStore) {
        self.store = store
        self.original = item
        self.name = item.name
        self.category = item.category
        self.placement = item.placement
        self.expirationDate = item.expirationDate
    }

    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Writes the edits back, keeping the item's id and untouched fields, and
    /// reschedules the alert + calendar event via ``FoodStore/updateItem(_:)``.
    func save() async {
        var updated = original
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.category = category
        updated.placement = placement
        // A hand-picked date is no longer an estimate.
        if updated.expirationDate != expirationDate {
            updated.expirationDate = expirationDate
            updated.isEstimatedExpiry = false
        }
        await store.updateItem(updated)
    }
}

// MARK: - Edit Item Sheet

/// Modal form for editing an existing pantry item's name, category (its icon /
/// "picture"), storage placement, and expiration date.
struct EditItemSheet: View {
    @StateObject private var viewModel: EditItemViewModel
    @Environment(\.dismiss) private var dismiss

    init(item: FoodItem, store: FoodStore) {
        _viewModel = StateObject(wrappedValue: EditItemViewModel(item: item, store: store))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    iconPreview

                    formField(label: "ITEM NAME", text: $viewModel.name, placeholder: "e.g. Baby Spinach")

                    pickerField(label: "CATEGORY") {
                        Picker("Category", selection: $viewModel.category) {
                            ForEach(FoodCategory.allCases, id: \.self) { c in
                                Label(c.rawValue, systemImage: c.icon).tag(c)
                            }
                        }
                    }

                    pickerField(label: "STORAGE") {
                        Picker("Placement", selection: $viewModel.placement) {
                            ForEach(StoragePlacement.allCases, id: \.self) { p in
                                Label(p.label, systemImage: p.icon).tag(p)
                            }
                        }
                    }

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

                    Button {
                        Task {
                            await viewModel.save()
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                            Text("Save Changes")
                        }
                    }
                    .buttonStyle(FTPrimaryButtonStyle())
                    .disabled(!viewModel.canSave)
                    .opacity(viewModel.canSave ? 1 : 0.5)
                    .padding(.top, FTSpacing.lg)
                }
                .padding(FTSpacing.xl)
            }
            // Dismiss the keyboard as soon as the form is scrolled, so the save
            // button below the fold becomes reachable.
            .scrollDismissesKeyboard(.immediately)
            .background(Color.ftSurface)
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.ftPrimary)
                }
                // A Done button dismisses the keyboard so the save button below the
                // fold (the form sits in a scroll view) is reachable.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                        .foregroundStyle(Color.ftPrimary)
                }
            }
        }
    }

    /// Large icon that previews the currently selected category (the "picture").
    private var iconPreview: some View {
        RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
            .fill(Color.ftSurfaceContainerLow)
            .frame(width: 96, height: 96)
            .overlay(
                Image(systemName: viewModel.category.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.ftOnSurfaceVariant)
            )
            .animation(.easeInOut(duration: 0.2), value: viewModel.category)
    }

    private func formField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color.ftOnSurfaceVariant)
            TextField(placeholder, text: text)
                .font(FTFonts.bodyLarge)
                .foregroundStyle(Color.ftPrimary)
                .tint(Color.ftPrimary)
                .padding(FTSpacing.lg)
                .background(Color.ftSurfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
        }
    }

    private func pickerField<P: View>(label: String, @ViewBuilder picker: () -> P) -> some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color.ftOnSurfaceVariant)
            picker()
                .pickerStyle(.menu)
                .tint(Color.ftPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, FTSpacing.md)
                .padding(.vertical, 4)
                .background(Color.ftSurfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
        }
    }
}

#Preview {
    PantryView(store: FoodStore())
}
