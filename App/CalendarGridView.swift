import SwiftUI
import Combine

// MARK: - Calendar View Model

/// Owns the month/selection state and all calendar date arithmetic for the grid.
@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var displayedMonth = Date()
    @Published var selectedDate: Date?

    let dayLabels = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]

    private let store: FoodStore
    private let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()

    init(store: FoodStore) {
        self.store = store
        store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: Data

    func items(expiringOn date: Date) -> [FoodItem] { store.items(expiringOn: date) }

    func expiringDots(for items: [FoodItem]) -> [Color] { items.map { $0.freshnessStatus.dotColor } }

    // MARK: Per-cell queries

    func isToday(_ date: Date) -> Bool { calendar.isDateInToday(date) }

    func isSelected(_ date: Date) -> Bool {
        selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
    }

    func isInDisplayedMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
    }

    func dayNumber(for date: Date) -> Int { calendar.component(.day, from: date) }

    // MARK: Navigation

    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    func previousMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
    }

    func nextMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
    }

    /// Dates for the displayed month, padded with `nil`s so the grid starts on the
    /// correct weekday and fills complete rows of seven.
    func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }

        let weekdayOfFirst = calendar.component(.weekday, from: firstDay) - 1
        var days: [Date?] = Array(repeating: nil, count: weekdayOfFirst)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }
}

// MARK: - Calendar Grid View (Monthly Expiration Overview)

/// Monthly calendar that marks days with colored expiry dots and drills into the
/// items expiring on a tapped date.
struct CalendarGridView: View {
    @StateObject private var viewModel: CalendarViewModel
    private let store: FoodStore
    /// The item currently being edited, driving the edit sheet.
    @State private var editingItem: FoodItem?

    init(store: FoodStore) {
        _viewModel = StateObject(wrappedValue: CalendarViewModel(store: store))
        self.store = store
    }

    var body: some View {
        VStack(spacing: 0) {
            calendarCard
            if let selected = viewModel.selectedDate {
                selectedDateItems(date: selected)
            }
        }
        .sheet(item: $editingItem) { item in
            EditItemSheet(item: item, store: store)
        }
    }

    // MARK: - Calendar Card

    private var calendarCard: some View {
        VStack(spacing: FTSpacing.lg) {
            // Month header
            HStack {
                Text(viewModel.monthYearString)
                    .font(FTFonts.headlineSmall)
                    .foregroundStyle(Color.ftOnSurface)
                Spacer()
                HStack(spacing: FTSpacing.sm) {
                    Button {
                        withAnimation(.spring(response: 0.3)) { viewModel.previousMonth() }
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Color.ftOutline)
                    }
                    Button {
                        withAnimation(.spring(response: 0.3)) { viewModel.nextMonth() }
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.ftOutline)
                    }
                }
            }

            // Day-of-week labels
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                ForEach(viewModel.dayLabels, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.ftOutline)
                        .frame(height: 24)
                }
            }

            // Date grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: FTSpacing.sm) {
                // Key by index: the padding slots are all `nil` and would collide
                // under `id: \.self`, so identify cells by their grid position.
                ForEach(Array(viewModel.daysInMonth().enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        dayCell(date: date)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.selectedDate = date
                                }
                            }
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }

            // Legend
            legendView
        }
        .padding(FTSpacing.xl)
        .background {
            ZStack {
                Color.ftSurfaceContainerLowest
                // Glassmorphism subtle overlay per design
                FTGradients.glassMorphism.opacity(0.3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
        .shadow(
            color: FTShadow.card.color,
            radius: FTShadow.card.radius,
            x: FTShadow.card.x,
            y: FTShadow.card.y
        )
    }

    // MARK: - Day Cell

    private func dayCell(date: Date) -> some View {
        let isToday = viewModel.isToday(date)
        let isSelected = viewModel.isSelected(date)
        let expiringItems = viewModel.items(expiringOn: date)
        let isCurrentMonth = viewModel.isInDisplayedMonth(date)
        let dots = Array(viewModel.expiringDots(for: expiringItems).prefix(3))

        return VStack(spacing: 2) {
            Text("\(viewModel.dayNumber(for: date))")
                .font(FTFonts.bodyMediumFont)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(
                    isCurrentMonth
                        ? (isToday ? Color.ftPrimary : Color.ftOnSurface)
                        : Color.ftSurfaceDim
                )

            if !dots.isEmpty {
                HStack(spacing: 2) {
                    // Index-based IDs: duplicate status colors are valid and must not collide.
                    ForEach(dots.indices, id: \.self) { index in
                        Circle()
                            .fill(dots[index])
                            .frame(width: 6, height: 6)
                    }
                }
            } else {
                Spacer().frame(height: 6)
            }
        }
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background(
            Group {
                if isSelected || isToday {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.ftPrimaryContainer.opacity(0.1))
                }
            }
        )
    }

    // MARK: - Legend

    private var legendView: some View {
        HStack(spacing: FTSpacing.lg) {
            ForEach([FreshnessStatus.safe, .warning, .critical], id: \.self) { status in
                HStack(spacing: 6) {
                    Circle()
                        .fill(status.dotColor)
                        .frame(width: 8, height: 8)
                    Text(status.label)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(Color.ftOutline)
                }
            }
        }
        .padding(.top, FTSpacing.lg)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.ftSurfaceContainerLow.opacity(0.5))
                .frame(height: 1)
        }
    }

    // MARK: - Selected Date Items

    private func selectedDateItems(date: Date) -> some View {
        let items = viewModel.items(expiringOn: date)
        let formatted = date.formatted(.dateTime.month(.wide).day())

        return VStack(alignment: .leading, spacing: FTSpacing.lg) {
            Text("Expiring on \(formatted)")
                .font(FTFonts.headlineSmall)
                .foregroundStyle(Color.ftOnSurface)
                .padding(.top, FTSpacing.xl)

            if items.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.ftPrimaryFixed)
                        Text("Nothing expiring")
                            .font(FTFonts.bodyMediumFont)
                            .foregroundStyle(Color.ftOnSurfaceVariant)
                    }
                    .padding(.vertical, FTSpacing.xl)
                    Spacer()
                }
            } else {
                ForEach(items) { item in
                    FoodItemCard(item: item)
                        .onTapGesture { editingItem = item }
                }
            }
        }
    }
}

// MARK: - Reusable Food Item Card

/// Reusable row card showing an item's icon, name, placement, and a freshness chip
/// with a colored status strip down the leading edge.
struct FoodItemCard: View {
    let item: FoodItem

    var body: some View {
        HStack(spacing: FTSpacing.lg) {
            // Category icon placeholder
            RoundedRectangle(cornerRadius: FTRadius.md)
                .fill(Color.ftSurfaceContainerLow)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: item.category.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(Color.ftOnSurfaceVariant)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(FTFonts.headlineSemiBold(18))
                    .foregroundStyle(Color.ftOnSurface)
                    .lineLimit(1)
                Text(item.isEstimatedExpiry ? "\(item.placementLabel) · Est. expiry" : item.placementLabel)
                    .font(FTFonts.bodyMediumFont)
                    .foregroundStyle(Color.ftOnSurfaceVariant)
                    .lineLimit(1)
            }

            Spacer()

            // Freshness chip
            Text(item.expiryLabel.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(item.freshnessStatus.chipForeground)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(item.freshnessStatus.chipBackground)
                .clipShape(Capsule())
        }
        .padding(FTSpacing.lg)
        .background(Color.ftSurfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.card, style: .continuous))
        .overlay(alignment: .leading) {
            // Left status strip
            UnevenRoundedRectangle(
                topLeadingRadius: FTRadius.card,
                bottomLeadingRadius: FTRadius.card
            )
            .fill(item.freshnessStatus.stripColor)
            .frame(width: 6)
        }
        .shadow(
            color: FTShadow.card.color,
            radius: FTShadow.card.radius / 2,
            x: 0,
            y: 2
        )
    }
}
