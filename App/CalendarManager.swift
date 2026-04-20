import SwiftUI
import EventKit

// MARK: - Calendar Manager (EventKit Integration)

@MainActor
final class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                return granted
            } catch {
                return false
            }
        } else {
            do {
                let granted = try await eventStore.requestAccess(to: .event)
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                return granted
            } catch {
                return false
            }
        }
    }

    func addExpirationEvent(for item: FoodItem) async -> String? {
        guard await requestAccess() else { return nil }

        let event = EKEvent(eventStore: eventStore)
        event.title = "🥬 \(item.name) expires"
        event.notes = "FreshTrack: \(item.name) (\(item.brand)) stored in \(item.placementLabel) is expiring."
        event.startDate = Calendar.current.startOfDay(for: item.expirationDate)
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.startDate)!
        event.isAllDay = true
        event.calendar = eventStore.defaultCalendarForNewEvents

        // Add 2-day-before alarm
        let alarm = EKAlarm(relativeOffset: -2 * 24 * 60 * 60) // -2 days in seconds
        event.addAlarm(alarm)

        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            return nil
        }
    }

    func removeEvent(identifier: String) {
        guard let event = eventStore.event(withIdentifier: identifier) else { return }
        try? eventStore.remove(event, span: .thisEvent)
    }
}
