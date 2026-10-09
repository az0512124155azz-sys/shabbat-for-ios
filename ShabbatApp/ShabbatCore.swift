import Foundation

public struct ShabCity {
    public let name: String
    public let nameEn: String
    public let nameFr: String
    public let lat: Double
    public let lon: Double
    public let tz: String
    public let country: String
    public let isGPS: Bool

    public func localizedName(_ language: String = ShabbatCore.language) -> String {
        switch language {
        case "fr":
            return nameFr.isEmpty ? (nameEn.isEmpty ? name : nameEn) : nameFr
        case "en":
            return nameEn.isEmpty ? name : nameEn
        default:
            return name
        }
    }
}

public enum ShabbatCore {
    public static let appGroup = "group.com.avishait.shabbat"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    public static var language: String {
        get {
            if let saved = defaults.string(forKey: "language"),
               ["he", "en", "fr"].contains(saved) {
                return saved
            }

            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "he"
            if preferred.hasPrefix("fr") { return "fr" }
            if preferred.hasPrefix("en") { return "en" }
            return "he"
        }
        set {
            guard ["he", "en", "fr"].contains(newValue) else { return }
            defaults.set(newValue, forKey: "language")
            // WidgetKit runs in a separate process. Flush the shared App Group
            // defaults before requesting timeline reloads so the extension sees
            // the newly selected language immediately.
            defaults.synchronize()
        }
    }

    public static func saveCity(
        name: String,
        nameEn: String = "",
        nameFr: String = "",
        lat: Double,
        lon: Double,
        tz: String,
        country: String = "",
        isGPS: Bool = false
    ) {
        defaults.set(
            [
                "n": name,
                "e": nameEn,
                "f": nameFr,
                "la": lat,
                "lo": lon,
                "tz": tz,
                "c": country,
                "gps": isGPS
            ] as [String: Any],
            forKey: "city"
        )
    }

    public static func loadCity() -> ShabCity {
        if let object = defaults.dictionary(forKey: "city"),
           let lat = number(object["la"]),
           let lon = number(object["lo"]) {
            let hebrewName = object["n"] as? String ?? "ירושלים"
            let englishName = object["e"] as? String ?? hebrewName
            return ShabCity(
                name: hebrewName,
                nameEn: englishName,
                nameFr: object["f"] as? String ?? englishName,
                lat: lat,
                lon: lon,
                tz: object["tz"] as? String ?? "Asia/Jerusalem",
                country: object["c"] as? String ?? "",
                isGPS: object["gps"] as? Bool ?? false
            )
        }

        return ShabCity(
            name: "ירושלים",
            nameEn: "Jerusalem",
            nameFr: "Jérusalem",
            lat: 31.7683,
            lon: 35.2137,
            tz: "Asia/Jerusalem",
            country: "ישראל",
            isGPS: false
        )
    }

    public static func todayKey(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: loadCity().tz) ?? .current
        return formatter.string(from: now)
    }

    public static func tefillinMap() -> [String: Bool] {
        (defaults.dictionary(forKey: "tef") as? [String: Bool]) ?? [:]
    }

    public static func isTefillinToday() -> Bool {
        tefillinMap()[todayKey()] ?? false
    }

    public static func setTefillin(_ key: String, _ value: Bool) {
        var map = tefillinMap()
        map[key] = value
        defaults.set(map, forKey: "tef")
    }

    public static func toggleTefillinToday() {
        setTefillin(todayKey(), !isTefillinToday())
    }

    public static var notifEnabled: Bool {
        get { defaults.bool(forKey: "notif") }
        set { defaults.set(newValue, forKey: "notif") }
    }

    public struct SnapshotEvent {
        public let title: String
        public let entry: String
        public let exit: String
        public let entryEpoch: Int64
        public let exitEpoch: Int64
    }

    public struct AppSnapshot {
        public let source: String
        public let sourceDate: String
        public let updatedAt: Int64
        public let city: String
        public let timezone: String
        public let latitude: Double
        public let longitude: Double
        public let sunrise: String
        public let nightfall: String
        public let eventTitle: String
        public let eventEntry: String
        public let eventExit: String
        public let eventEntryEpoch: Int64
        public let eventExitEpoch: Int64
        public let parasha: String
        public let events: [SnapshotEvent]
    }

    @discardableResult
    public static func saveAppSnapshot(_ object: [String: Any]) -> Bool {
        guard (object["source"] as? String) == "hebcal" else { return false }

        let rawEvents = object["events"] as? [[String: Any]] ?? []
        let events: [[String: Any]] = rawEvents.map { event in
            [
                "title": event["title"] as? String ?? "",
                "entry": event["entry"] as? String ?? "",
                "exit": event["exit"] as? String ?? "",
                "entryEpoch": int64(event["entryEpoch"]),
                "exitEpoch": int64(event["exitEpoch"])
            ]
        }

        let snapshot: [String: Any] = [
            "source": "hebcal",
            "sourceDate": object["sourceDate"] as? String ?? "",
            "updatedAt": int64(object["updatedAt"]),
            "city": object["city"] as? String ?? "",
            "timezone": object["timezone"] as? String ?? "",
            "latitude": number(object["latitude"]) ?? 0,
            "longitude": number(object["longitude"]) ?? 0,
            "sunrise": object["sunrise"] as? String ?? "",
            "nightfall": object["nightfall"] as? String ?? "",
            "eventTitle": object["eventTitle"] as? String ?? "",
            "eventEntry": object["eventEntry"] as? String ?? "",
            "eventExit": object["eventExit"] as? String ?? "",
            "eventEntryEpoch": int64(object["eventEntryEpoch"]),
            "eventExitEpoch": int64(object["eventExitEpoch"]),
            "parasha": object["parasha"] as? String ?? "",
            "events": events
        ]

        defaults.set(snapshot, forKey: "app_snapshot")
        return true
    }

    public static func appSnapshot() -> AppSnapshot? {
        guard
            let object = defaults.dictionary(forKey: "app_snapshot"),
            (object["source"] as? String) == "hebcal"
        else {
            return nil
        }

        let rawEvents = object["events"] as? [[String: Any]] ?? []
        let events = rawEvents.map { event in
            SnapshotEvent(
                title: event["title"] as? String ?? "",
                entry: event["entry"] as? String ?? "",
                exit: event["exit"] as? String ?? "",
                entryEpoch: int64(event["entryEpoch"]),
                exitEpoch: int64(event["exitEpoch"])
            )
        }

        return AppSnapshot(
            source: "hebcal",
            sourceDate: object["sourceDate"] as? String ?? "",
            updatedAt: int64(object["updatedAt"]),
            city: object["city"] as? String ?? "",
            timezone: object["timezone"] as? String ?? "",
            latitude: number(object["latitude"]) ?? 0,
            longitude: number(object["longitude"]) ?? 0,
            sunrise: object["sunrise"] as? String ?? "",
            nightfall: object["nightfall"] as? String ?? "",
            eventTitle: object["eventTitle"] as? String ?? "",
            eventEntry: object["eventEntry"] as? String ?? "",
            eventExit: object["eventExit"] as? String ?? "",
            eventEntryEpoch: int64(object["eventEntryEpoch"]),
            eventExitEpoch: int64(object["eventExitEpoch"]),
            parasha: object["parasha"] as? String ?? "",
            events: events
        )
    }

    public static func clearAppSnapshot() {
        defaults.removeObject(forKey: "app_snapshot")
    }

    private static func int64(_ value: Any?) -> Int64 {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? Double { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        if let value = value as? String { return Int64(value) ?? 0 }
        return 0
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }
}
