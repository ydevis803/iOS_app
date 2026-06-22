import Foundation
import UserNotifications

// MARK: - Notification Manager (UNUserNotificationCenter)

/// Wraps `UNUserNotificationCenter` to schedule and cancel local expiry reminders
/// that fire two days before an item's expiration date.
@MainActor
final class NotificationManager: ObservableObject {
    @Published var isAuthorized = false

    /// Requests alert/badge/sound authorization and records the result in ``isAuthorized``.
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    /// Schedule a notification 2 days before the expiration date.
    func scheduleExpiryAlert(for item: FoodItem) -> String? {
        let content = UNMutableNotificationContent()
        content.title = "⏰ \(item.name) Expiring Soon"
        content.body = "\(item.name) in your \(item.placementLabel) expires in 2 days. Time to use it up!"
        content.sound = .default
        content.categoryIdentifier = "EXPIRY_ALERT"

        // Fire date = expiry date minus 2 days
        guard let fireDate = Calendar.current.date(byAdding: .day, value: -2, to: item.expirationDate) else {
            return nil
        }

        // Don't schedule if fire date is in the past
        guard fireDate > Date() else { return nil }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: fireDate)!
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = "freshtrack-expiry-\(item.id.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification scheduling error: \(error.localizedDescription)")
            }
        }

        return id
    }

    /// Cancels the pending notification with the given identifier.
    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Cancels every pending FreshTrack notification.
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
