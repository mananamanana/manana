import Foundation
import UserNotifications

/// Schedules the daily "today's quote" reminder.
///
/// Local notifications can't reach out to the network at delivery time, so
/// there's no way to know the exact weather at tomorrow 8am when we schedule
/// today. As a best effort, every time the in-app weather condition changes
/// we recompute the notification body and reschedule a one-shot alert for the
/// next occurrence of the reminder time — so the copy is at least as fresh as
/// the last time the app was open.
@MainActor
final class NotificationManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var notificationHour: Int {
        didSet { UserDefaults.standard.set(notificationHour, forKey: Keys.hour) }
    }
    @Published var notificationMinute: Int {
        didSet { UserDefaults.standard.set(notificationMinute, forKey: Keys.minute) }
    }
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Keys.enabled)
            if !notificationsEnabled { cancelPending() }
        }
    }

    private enum Keys {
        static let hour = "notification.hour"
        static let minute = "notification.minute"
        static let enabled = "notification.enabled"
    }

    private static let requestIdentifier = "daily-quote-notification"

    init() {
        let defaults = UserDefaults.standard
        notificationHour = defaults.object(forKey: Keys.hour) as? Int ?? 8
        notificationMinute = defaults.object(forKey: Keys.minute) as? Int ?? 0
        notificationsEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in self.isAuthorized = granted }
        }
    }

    func rescheduleForNextOccurrence(bodyProvider: () -> String) {
        guard notificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])

        guard let fireDate = nextOccurrence(hour: notificationHour, minute: notificationMinute) else { return }

        let content = UNMutableNotificationContent()
        content.title = "오늘의 날씨와 어울리는 문장이 도착했어요"
        content.body = bodyProvider()
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: Self.requestIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    private func cancelPending() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
    }

    private func nextOccurrence(hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        guard let today = calendar.date(from: components) else { return nil }
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
    }
}
