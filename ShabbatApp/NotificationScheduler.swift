import Foundation
import UserNotifications

enum NotificationScheduler {

    /// Re-creates future Shabbat / Yom-Tov reminders. Overlapping observances
    /// are merged by ShabbatCore, so a holiday joined to Shabbat produces one
    /// entry reminder and one final exit reminder.
    static func refresh() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard ShabbatCore.notifEnabled else { return }

        let city = ShabbatCore.loadCity()
        let now = Date()
        var cursor = now

        // Keep comfortably below iOS's 64-pending-notification limit.
        for index in 0..<16 {
            let event = ShabbatCore.nextObservance(city, now: cursor)

            let erevFire = event.entry.addingTimeInterval(-3 * 3600)
            if erevFire > now {
                let copy = erevCopy(
                    event: event.localizedTitle(),
                    time: ShabbatCore.fmt(event.entry, tz: city.tz)
                )
                schedule(
                    id: "observance-erev-\(index)-\(Int(event.entry.timeIntervalSince1970))",
                    title: copy.0,
                    body: copy.1,
                    at: erevFire,
                    timeZoneID: city.tz
                )
            }

            let exitFire = event.exit.addingTimeInterval(10 * 60)
            if exitFire > now {
                let copy = motzaeiCopy(event: event.localizedTitle())
                schedule(
                    id: "observance-exit-\(index)-\(Int(event.exit.timeIntervalSince1970))",
                    title: copy.0,
                    body: copy.1,
                    at: exitFire,
                    timeZoneID: city.tz
                )
            }

            // Ask for the following observance rather than rediscovering this one.
            cursor = event.exit.addingTimeInterval(60)
        }
    }

    private static func erevCopy(event: String, time: String) -> (String, String) {
        switch ShabbatCore.language {
        case "en":
            return (
                "🕯️ \(event)",
                "\(event) begins today at \(time). About three hours remain — time to get ready ✨"
            )
        case "fr":
            return (
                "🕯️ \(event)",
                "\(event) commence aujourd’hui à \(time). Il reste environ trois heures pour se préparer ✨"
            )
        default:
            return (
                "🕯️ \(event)",
                "זמן כניסת \(event) היום בשעה \(time). נותרו כשלוש שעות — זמן להתארגן ✨"
            )
        }
    }

    private static func motzaeiCopy(event: String) -> (String, String) {
        switch ShabbatCore.language {
        case "en":
            return (
                "⭐ \(event) has ended",
                "The observance has ended. Wishing you a wonderful and blessed week!"
            )
        case "fr":
            return (
                "⭐ Fin de \(event)",
                "La fête ou le Chabbat est terminé. Nous vous souhaitons une merveilleuse semaine !"
            )
        default:
            return (
                "⭐ צאת \(event)",
                "השבת או החג הסתיימו. שיהיה לך שבוע נפלא ומבורך!"
            )
        }
    }

    private static func schedule(
        id: String,
        title: String,
        body: String,
        at date: Date,
        timeZoneID: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.timeZone = calendar.timeZone

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        )
    }

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
