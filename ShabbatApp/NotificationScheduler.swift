import Foundation
import UserNotifications

enum NotificationScheduler {

    static func refresh() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard ShabbatCore.notifEnabled,
              let snapshot = ShabbatCore.appSnapshot()
        else {
            return
        }

        let now = Date().timeIntervalSince1970 * 1000.0
        let futureEntry = snapshot.events
            .filter { $0.entryEpoch > 0 && Double($0.entryEpoch) - 3 * 60 * 60 * 1000 > now + 60_000 }
            .min { $0.entryEpoch < $1.entryEpoch }

        let futureExit = snapshot.events
            .filter { $0.exitEpoch > 0 && Double($0.exitEpoch) + 10 * 60 * 1000 > now + 60_000 }
            .min { $0.exitEpoch < $1.exitEpoch }

        if let event = futureEntry {
            let fire = Date(timeIntervalSince1970: Double(event.entryEpoch) / 1000.0)
                .addingTimeInterval(-3 * 60 * 60)
            let copy = erevCopy(event: event.title, time: event.entry)
            schedule(
                id: "observance-erev",
                title: copy.0,
                body: copy.1,
                at: fire,
                timeZoneID: snapshot.timezone
            )
        }

        if let event = futureExit {
            let fire = Date(timeIntervalSince1970: Double(event.exitEpoch) / 1000.0)
                .addingTimeInterval(10 * 60)
            let copy = motzaeiCopy(event: event.title)
            schedule(
                id: "observance-exit",
                title: copy.0,
                body: copy.1,
                at: fire,
                timeZoneID: snapshot.timezone
            )
        }
    }

    static func disablePendingOnly() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
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

    private enum ExitEventKind {
        case shabbat
        case holiday
        case combined
    }

    private static func exitEventKind(_ event: String) -> ExitEventKind {
        let normalized = event
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        let isShabbat =
            normalized.contains("שבת") ||
            normalized.contains("shabbat") ||
            normalized.contains("chabbat")

        let isCombined = isShabbat && event.contains("+")
        if isCombined { return .combined }
        return isShabbat ? .shabbat : .holiday
    }

    private static func motzaeiCopy(event: String) -> (String, String) {
        switch (ShabbatCore.language, exitEventKind(event)) {
        case ("en", .shabbat):
            return (
                "⭐ Shabbat has ended",
                "Shabbat has ended. Shavua Tov!"
            )
        case ("en", .combined):
            return (
                "⭐ Shabbat and holiday have ended",
                "\(event) has ended. Wishing you a wonderful and blessed week!"
            )
        case ("en", .holiday):
            return (
                "⭐ \(event) has ended",
                "\(event) has ended."
            )

        case ("fr", .shabbat):
            return (
                "⭐ Fin du Chabbat",
                "Le Chabbat est terminé. Chavoua Tov !"
            )
        case ("fr", .combined):
            return (
                "⭐ Fin du Chabbat et de la fête",
                "\(event) est terminé. Nous vous souhaitons une excellente semaine !"
            )
        case ("fr", .holiday):
            return (
                "⭐ Fin de \(event)",
                "\(event) est terminé."
            )

        case (_, .shabbat):
            return (
                "⭐ צאת השבת",
                "השבת הסתיימה. שבוע טוב ומבורך!"
            )
        case (_, .combined):
            return (
                "⭐ צאת שבת והחג",
                "\(event) הסתיימו. שבוע טוב ומבורך!"
            )
        case (_, .holiday):
            return (
                "⭐ צאת \(event)",
                "\(event) הסתיים."
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
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            DispatchQueue.main.async {
                ShabbatCore.notifEnabled = granted
                if granted { refresh() }
                completion(granted)
            }
        }
    }

    static func disable() {
        ShabbatCore.notifEnabled = false
        disablePendingOnly()
    }
}
