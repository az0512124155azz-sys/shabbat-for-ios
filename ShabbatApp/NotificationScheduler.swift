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
                    let copy = erevCopy(time: ShabbatCore.fmt(c, tz: city.tz))
                    schedule(
                        id: "shab-erev-\(week)",
                        title: copy.0, body: copy.1, at: fire, timeZoneID: city.tz
                    )
                }
            }
            if let h = t.havdalah {
                let fireMotzaei = h.addingTimeInterval(10 * 60)   // 10 minutes after Shabbat exit
                if fireMotzaei > now {
                    let copy = motzaeiCopy()
                    schedule(
                        id: "shab-motzaei-\(week)",
                        title: copy.0, body: copy.1, at: fireMotzaei, timeZoneID: city.tz
                    )
                }
            }
        }
    }

    private static func erevCopy(time: String) -> (String, String) {
        switch ShabbatCore.language {
        case "en": return ("🕯️ Shabbat Shalom!", "Shabbat begins today at \(time). About three hours remain — time to get ready for Shabbat ✨")
        case "fr": return ("🕯️ Chabbat Chalom !", "Chabbat commence aujourd’hui à \(time). Il reste environ trois heures pour se préparer ✨")
        default: return ("🕯️ שבת שלום!", "השבת נכנסת היום בשעה \(time). נותרו כשלוש שעות — זמן להתארגן ולקבל את השבת ✨")
        }
    }

    private static func motzaeiCopy() -> (String, String) {
        switch ShabbatCore.language {
        case "en": return ("⭐ Shavua Tov!", "Shabbat has ended. Wishing you a wonderful and blessed week!")
        case "fr": return ("⭐ Chavoua Tov !", "Chabbat est terminé. Nous vous souhaitons une merveilleuse semaine !")
        default: return ("⭐ שבוע טוב!", "השבת יצאה. שיהיה לך שבוע נפלא ומבורך!")
        }
    }

    private static func schedule(id: String, title: String, body: String, at date: Date, timeZoneID: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        comps.timeZone = calendar.timeZone
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
