import Foundation
import UserNotifications

enum NotificationScheduler {

    /// Re-creates all pending Shabbat notifications for the coming ~2 months.
    /// iOS limits pending local notifications to 64, so 8 weeks x 2 is safe.
    static func refresh() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard ShabbatCore.notifEnabled else { return }
        let city = ShabbatCore.loadCity()
        let now = Date()
        for week in 0..<8 {
            let ref = now.addingTimeInterval(Double(week) * 7 * 86400)
            let t = ShabbatCore.nextShabbat(city, now: ref)
            if let c = t.candle {
                let fire = c.addingTimeInterval(-3 * 3600)
                if fire > now {
                    schedule(
                        id: "shab-erev-\(week)",
                        title: "🕯️ שבת שלום!",
                        body: "השבת נכנסת היום בשעה \(ShabbatCore.fmt(c, tz: city.tz)). נותרו כשלוש שעות — זמן להתארגן ולקבל את השבת ✨",
                        at: fire
                    )
                }
            }
            if let h = t.havdalah {
                let fire = h.addingTimeInterval(10 * 60)
                if fire > now {
                    schedule(
                        id: "shab-motzaei-\(week)",
                        title: "⭐ שבוע טוב!",
                        body: "השבת יצאה. שיהיה לך שבוע נפלא ומבורך!",
                        at: fire
                    )
                }
            }
        }
    }

    private static func schedule(id: String, title: String, body: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trig = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trig)
        )
    }

    /// Asks the system permission dialog, then schedules if granted.
    static func enable(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                ShabbatCore.notifEnabled = granted
                if granted { refresh() }
                completion(granted)
            }
        }
    }

    static func disable() {
        ShabbatCore.notifEnabled = false
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
