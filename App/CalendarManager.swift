import SwiftUI
import EventKit

// MARK: - Calendar Manager (EventKit Integration)

/// Wraps EventKit to create and remove all-day expiry events (with a 2-day-before alarm)
/// in the user's default calendar.
@MainActor
final class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    /// Requests calendar write access, using the iOS 17+ full-access API where available.
    /// - Returns: `true` if access was granted.
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

    /// Creates an all-day expiry event with a 2-day-before alarm for the item.
    /// - Returns: The new event's identifier, or `nil` if access was denied or saving failed.
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

    /// Removes the calendar event with the given identifier, if it still exists.
    func removeEvent(identifier: String) {
        guard let event = eventStore.event(withIdentifier: identifier) else { return }
        try? eventStore.remove(event, span: .thisEvent)
    }
}
