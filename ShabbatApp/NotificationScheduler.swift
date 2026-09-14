import Foundation
import UserNotifications

enum NotificationScheduler {

    /// Re-creates notifications for the next Shabbat/Yom Tov periods.
    /// Consecutive or overlapping days are represented by one observance, so a
    /// Motzaei notification cannot fire in the middle of a holiday sequence.
    static func refresh() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard ShabbatCore.notifEnabled else { return }
        let city = ShabbatCore.loadCity()
        let now = Date()
        var cursor = now
        for index in 0..<12 {
            let event = ShabbatCore.nextObservance(city, now: cursor)
            let title = event.localizedTitle()
            let fireErev = event.entry.addingTimeInterval(-3 * 3600)
            if fireErev > now {
                let copy = erevCopy(event: title, time: ShabbatCore.fmt(event.entry, tz: city.tz))
                schedule(id: "observance-erev-\(index)", title: copy.0, body: copy.1, at: fireErev, timeZoneID: city.tz)
            }
            let fireMotzaei = event.exit.addingTimeInterval(10 * 60)
            if fireMotzaei > now {
                let copy = motzaeiCopy(event: title)
                schedule(id: "observance-motzaei-\(index)", title: copy.0, body: copy.1, at: fireMotzaei, timeZoneID: city.tz)
            }
            cursor = event.exit.addingTimeInterval(60)
        }
    }

    private static func erevCopy(event: String, time: String) -> (String, String) {
        switch ShabbatCore.language {
        case "en": return ("🕯️ \(event)", "\(event) begins today at \(time). About three hours remain — time to get ready ✨")
        case "fr": return ("🕯️ \(event)", "\(event) commence aujourd’hui à \(time). Il reste environ trois heures pour se préparer ✨")
        default: return ("🕯️ \(event)", "זמן כניסת \(event) היום בשעה \(time). נותרו כשלוש שעות — זמן להתארגן ✨")
        }
    }

    private static func motzaeiCopy(event: String) -> (String, String) {
        switch ShabbatCore.language {
        case "en": return ("⭐ \(event) has ended", "The observance has ended. Wishing you a wonderful and blessed week!")
        case "fr": return ("⭐ Fin de \(event)", "La fête est terminée. Nous vous souhaitons une merveilleuse semaine !")
        default: return ("⭐ \(event) יצא", "השבת או החג הסתיימו. שיהיה לך שבוע נפלא ומבורך!")
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
