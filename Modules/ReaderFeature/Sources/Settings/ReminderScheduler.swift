import UserNotifications

/// Schedules the optional daily reading reminder. A repeating local
/// notification at the chosen hour; toggling it off clears the pending request.
enum ReminderScheduler {
    static let identifier = "daily-reading-reminder"

    /// Request permission (first time) and (re)schedule a daily reminder.
    static func enable(hour: Int, minute: Int = 0) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            var time = DateComponents()
            time.hour = hour
            time.minute = minute

            let content = UNMutableNotificationContent()
            content.title = "常道"
            content.body = "今日一章，静心一读。"
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
            )
            // Re-resolve the center inside the handler to avoid capturing a
            // non-Sendable instance across the closure boundary.
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.add(request)
        }
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
