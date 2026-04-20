import SwiftUI

// MARK: - Shopping List View

struct ShoppingListView: View {
    @EnvironmentObject var store: FoodStore
    @State private var newItemName = ""
    @State private var isAddingItem = false

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.lg) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "cart")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.ftOnSurface)
                Text("Shopping List")
                    .font(FTFonts.headlineMedium)
                    .foregroundStyle(Color.ftOnSurface)
            }

            // List
            VStack(spacing: 0) {
                ForEach(store.shoppingList) { item in
                    shoppingRow(item: item)

                    if item.id != store.shoppingList.last?.id {
                        Divider()
                            .foregroundStyle(Color.ftSurfaceVariant.opacity(0.3))
                            .padding(.horizontal, FTSpacing.lg)
                    }
                }
            }
            .background(Color.ftSurfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.card, style: .continuous))
            .shadow(
                color: FTShadow.card.color,
                radius: FTShadow.card.radius / 2,
                x: 0,
                y: 2
            )

            // Add item
            if isAddingItem {
                HStack(spacing: FTSpacing.sm) {
                    TextField("Item name", text: $newItemName)
                        .font(FTFonts.bodyLarge)
                        .padding(FTSpacing.md)
                        .background(Color.ftSurfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
                        .onSubmit { addNewItem() }

                    Button {
                        addNewItem()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.ftPrimary)
                    }
                    .disabled(newItemName.isEmpty)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button {
                withAnimation(.spring(response: 0.3)) {
                    isAddingItem.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                    Text("Add Item")
                        .font(FTFonts.bodyMedium(14))
                }
                .foregroundStyle(Color.ftPrimary)
                .padding(FTSpacing.sm)
            }
        }
    }

    // MARK: - Shopping Row

    private func shoppingRow(item: ShoppingItem) -> some View {
        HStack(spacing: FTSpacing.lg) {
            // Checkbox
            Button {
                withAnimation(.spring(response: 0.2)) {
                    store.toggleShoppingItem(item)
                }
            } label: {
                if item.isChecked {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.ftPrimary)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.ftOnPrimary)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.ftOutlineVariant, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(FTFonts.bodyMedium(14))
                    .foregroundStyle(Color.ftOnSurface)
                    .strikethrough(item.isChecked)
                    .opacity(item.isChecked ? 0.5 : 1)

                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.system(size: 12))
                        .foregroundStyle(
                            item.note.lowercased().contains("expired")
                                ? Color.ftError
                                : Color.ftOnSurfaceVariant
                        )
                        .opacity(item.isChecked ? 0.5 : 1)
                }
            }

            Spacer()

            Button {
                withAnimation { store.removeShoppingItem(item) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.ftOnSurfaceVariant)
            }
            .opacity(0.6)
        }
        .padding(FTSpacing.lg)
        .background(item.isChecked ? Color.ftSurfaceContainerLow.opacity(0.5) : Color.clear)
        .contentShape(Rectangle())
    }

    private func addNewItem() {
        guard !newItemName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        store.addToShoppingList(name: newItemName)
        newItemName = ""
        withAnimation(.spring(response: 0.3)) {
            isAddingItem = false
        }
    }
}

#Preview {
    ShoppingListView()
        .environmentObject(FoodStore())
        .padding()
}
