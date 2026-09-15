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
        if language == "en", !nameEn.isEmpty { return nameEn }
        if language == "fr", !nameFr.isEmpty { return nameFr }
        return name
    }
}

public struct ShabObservance {
    public let names: [String]
    public let entry: Date
    public let exit: Date

    public func localizedTitle(_ language: String = ShabbatCore.language) -> String {
        names.map { ShabbatCore.localizedObservanceName($0, language: language) }
            .joined(separator: " + ")
    }
}

/// Native port of the calculations used by the Android app and shabbat.html.
/// Shared by the app and WidgetKit extension through the App Group.
public enum ShabbatCore {

    public static let appGroup = "group.com.avishait.shabbat"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    // MARK: - Language / city

    public static var language: String {
        get {
            if let saved = defaults.string(forKey: "language"), ["he", "en", "fr"].contains(saved) {
                return saved
            }
            let code = Locale.preferredLanguages.first?.lowercased() ?? "he"
            return code.hasPrefix("fr") ? "fr" : (code.hasPrefix("en") ? "en" : "he")
        }
        set {
            if ["he", "en", "fr"].contains(newValue) {
                defaults.set(newValue, forKey: "language")
            }
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
            ["n": name, "e": nameEn, "f": nameFr, "la": lat, "lo": lon, "tz": tz, "c": country, "gps": isGPS] as [String: Any],
            forKey: "city"
        )
    }

    public static func loadCity() -> ShabCity {
        if let d = defaults.dictionary(forKey: "city"),
           let la = d["la"] as? Double,
           let lo = d["lo"] as? Double {
            return ShabCity(
                name: d["n"] as? String ?? "ירושלים",
                nameEn: d["e"] as? String ?? "",
                nameFr: d["f"] as? String ?? "",
                lat: la,
                lon: lo,
                tz: d["tz"] as? String ?? "Asia/Jerusalem",
                country: d["c"] as? String ?? "",
                isGPS: d["gps"] as? Bool ?? false
            )
        }
        return ShabCity(
            name: "ירושלים",
            nameEn: "Jerusalem",
            nameFr: "Jérusalem",
            lat: 31.7683,
            lon: 35.2137,
            tz: "Asia/Jerusalem",
            country: "IL",
            isGPS: false
        )
    }

    // MARK: - Tefillin

    /// Uses the selected city's calendar day instead of UTC, preventing the
    /// Tefillin check mark from moving to the next day at the wrong local time.
    public static func todayKey(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: loadCity().tz) ?? .current
        return f.string(from: now)
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

    // MARK: - Notifications

    public static var notifEnabled: Bool {
        get { defaults.bool(forKey: "notif") }
        set { defaults.set(newValue, forKey: "notif") }
    }

    // MARK: - Solar calculations (NOAA, matching Android / web)

    private static func julianDay(_ y0: Int, _ m0: Int, _ d: Int) -> Double {
        var y = y0
        var m = m0
        if m <= 2 { y -= 1; m += 12 }
        let a = floor(Double(y) / 100.0)
        let b = 2.0 - a + floor(a / 4.0)
        return floor(365.25 * (Double(y) + 4716.0)) + floor(30.6001 * Double(m + 1)) + Double(d) + b - 1524.5
    }

    private static func normalizedDegrees(_ value: Double) -> Double {
        let r = value.truncatingRemainder(dividingBy: 360.0)
        return r < 0 ? r + 360.0 : r
    }

    public static func sol(
        lat: Double,
        lng: Double,
        day: Date,
        rising: Bool,
        zenith: Double,
        timeZone: TimeZone = .current
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dc = calendar.dateComponents([.year, .month, .day], from: day)
        guard let year = dc.year, let month = dc.month, let date = dc.day else { return nil }

        let jd = julianDay(year, month, date)
        let t = (jd - 2451545.0) / 36525.0
        let l0 = normalizedDegrees(280.46646 + 36000.76983 * t + 0.0003032 * t * t)
        let m = normalizedDegrees(357.52911 + 35999.05029 * t - 0.0001537 * t * t)
        let mr = m * .pi / 180.0

        let e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t
        let c = sin(mr) * (1.914602 - 0.004817 * t - 0.000014 * t * t)
            + sin(2.0 * mr) * (0.019993 - 0.000101 * t)
            + sin(3.0 * mr) * 0.000289

        let trueLong = l0 + c
        let omega = 125.04 - 1934.136 * t
        let lambda = (trueLong - 0.00569 - 0.00478 * sin(omega * .pi / 180.0)) * .pi / 180.0
        let e0 = 23.0 + 26.0 / 60.0 + 21.448 / 3600.0
            - t * (46.815 + t * (0.00059 - t * 0.001813)) / 3600.0
        let eps = (e0 + 0.00256 * cos(omega * .pi / 180.0)) * .pi / 180.0

        let sinDeclination = sin(eps) * sin(lambda)
        let cosDeclination = cos(asin(sinDeclination))
        let latRad = lat * .pi / 180.0
        let yTerm = tan(eps / 2.0) * tan(eps / 2.0)
        let l0Rad = l0 * .pi / 180.0

        let equationOfTime = 4.0 * (
            yTerm * sin(2.0 * l0Rad)
            - 2.0 * e * sin(mr)
            + 4.0 * e * yTerm * sin(mr) * cos(2.0 * l0Rad)
            - 0.5 * yTerm * yTerm * sin(4.0 * l0Rad)
            - 1.25 * e * e * sin(2.0 * mr)
        ) * 180.0 / .pi

        let cosH = (cos(zenith * .pi / 180.0) - sin(latRad) * sinDeclination)
            / (cos(latRad) * cosDeclination)
        guard cosH >= -1.0, cosH <= 1.0 else { return nil }

        let h0 = acos(cosH) * 180.0 / .pi
        let solarNoonMinutes = 720.0 - 4.0 * lng - equationOfTime
        let eventMinutes = rising ? solarNoonMinutes - 4.0 * h0 : solarNoonMinutes + 4.0 * h0
        let utcHours = ((eventMinutes / 60.0).truncatingRemainder(dividingBy: 24.0) + 24.0)
            .truncatingRemainder(dividingBy: 24.0)
        let hour = Int(floor(utcHours))
        let minuteFloat = (utcHours - Double(hour)) * 60.0
        let minute = Int(floor(minuteFloat))
        let second = Int(floor((minuteFloat - Double(minute)) * 60.0))

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = date
        parts.hour = hour
        parts.minute = minute
        parts.second = second
        return utc.date(from: parts)
    }

    public static func sunrise(_ city: ShabCity, _ day: Date) -> Date? {
        sol(lat: city.lat, lng: city.lon, day: day, rising: true, zenith: 90.833, timeZone: TimeZone(identifier: city.tz) ?? .current)
    }

    public static func sunset(_ city: ShabCity, _ day: Date) -> Date? {
        sol(lat: city.lat, lng: city.lon, day: day, rising: false, zenith: 90.833, timeZone: TimeZone(identifier: city.tz) ?? .current)
    }

    public static func tzeit(_ city: ShabCity, _ day: Date) -> Date? {
        sol(lat: city.lat, lng: city.lon, day: day, rising: false, zenith: 96.0, timeZone: TimeZone(identifier: city.tz) ?? .current)
    }

    public static func havdalah(_ city: ShabCity, saturday: Date) -> Date? {
        sol(lat: city.lat, lng: city.lon, day: saturday, rising: false, zenith: 98.5, timeZone: TimeZone(identifier: city.tz) ?? .current)
    }

    private static func distanceKm(_ aLat: Double, _ aLon: Double, _ bLat: Double, _ bLon: Double) -> Double {
        let radius = 6371.0
        let p = Double.pi / 180.0
        let dLat = (bLat - aLat) * p
        let dLon = (bLon - aLon) * p
        let a = sin(dLat / 2.0) * sin(dLat / 2.0)
            + cos(aLat * p) * cos(bLat * p) * sin(dLon / 2.0) * sin(dLon / 2.0)
        return radius * 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
    }

    public static func candleOffsetMinutes(_ city: ShabCity) -> Int {
        if city.isGPS {
            if distanceKm(city.lat, city.lon, 31.7683, 35.2137) <= 15.0 { return 40 }
            if distanceKm(city.lat, city.lon, 32.7940, 34.9896) <= 15.0 { return 30 }
        }
        if city.name == "ירושלים" || city.nameEn.caseInsensitiveCompare("Jerusalem") == .orderedSame { return 40 }
        if city.name == "חיפה" || city.nameEn.caseInsensitiveCompare("Haifa") == .orderedSame { return 30 }
        let country = city.country.lowercased()
        return city.tz == "Asia/Jerusalem" || ["il", "israel", "israël", "ישראל"].contains(country) ? 20 : 18
    }

    public static func candle(_ city: ShabCity, friday: Date) -> Date? {
        sunset(city, friday).map { $0.addingTimeInterval(TimeInterval(-candleOffsetMinutes(city) * 60)) }
    }

    public static func todayNoon(_ now: Date = Date(), timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
    }

    // MARK: - Shabbat / Yom Tov observances

    public static func nextShabbat(
        _ city: ShabCity,
        now: Date = Date()
    ) -> (friday: Date, saturday: Date, candle: Date?, havdalah: Date?) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: city.tz) ?? .current
        let noon = todayNoon(now, timeZone: calendar.timeZone)
        let weekday = calendar.component(.weekday, from: now) // 1=Sun ... 6=Fri, 7=Sat

        func nextWeekday(_ from: Date, _ target: Int) -> Date {
            let current = calendar.component(.weekday, from: from)
            var diff = (target - current + 7) % 7
            if diff == 0 { diff = 7 }
            return calendar.date(byAdding: .day, value: diff, to: from) ?? from
        }

        let friday: Date
        let saturday: Date
        if weekday == 7 {
            if let exit = havdalah(city, saturday: noon), now < exit {
                saturday = noon
                friday = calendar.date(byAdding: .day, value: -1, to: noon) ?? noon
            } else {
                friday = nextWeekday(noon, 6)
                saturday = calendar.date(byAdding: .day, value: 1, to: friday) ?? friday
            }
        } else if weekday == 6 {
            friday = noon
            saturday = calendar.date(byAdding: .day, value: 1, to: noon) ?? noon
        } else {
            friday = nextWeekday(noon, 6)
            saturday = calendar.date(byAdding: .day, value: 1, to: friday) ?? friday
        }
        return (friday, saturday, candle(city, friday: friday), havdalah(city, saturday: saturday))
    }

    public static func nextObservance(_ city: ShabCity, now: Date = Date()) -> ShabObservance {
        var raw: [ShabObservance] = []
        var seenMinutes = Set<Int64>()

        for week in 0..<14 {
            let reference = now.addingTimeInterval(TimeInterval(week) * 7.0 * 86400.0)
            let shabbat = nextShabbat(city, now: reference)
            if let entry = shabbat.candle, let exit = shabbat.havdalah {
                let minute = Int64(entry.timeIntervalSince1970 / 60.0)
                if seenMinutes.insert(minute).inserted {
                    raw.append(ShabObservance(names: ["שבת"], entry: entry, exit: exit))
                }
            }
        }

        let tz = TimeZone(identifier: city.tz) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let gregorianYear = calendar.component(.year, from: now)
        let country = city.country.lowercased()
        let israel = city.tz == "Asia/Jerusalem" || ["il", "israel", "israël", "ישראל"].contains(country)

        for hebrewYear in [gregorianYear + 3759, gregorianYear + 3760, gregorianYear + 3761] {
            for holiday in yomTovDates(hebrewYear, israel: israel, timeZone: tz) {
                guard let eve = calendar.date(byAdding: .day, value: -1, to: holiday.first),
                      let entry = candle(city, friday: eve),
                      let exit = havdalah(city, saturday: holiday.last) else { continue }
                raw.append(ShabObservance(names: [holiday.name], entry: entry, exit: exit))
            }
        }

        raw.sort { $0.entry < $1.entry }
        var merged: [ShabObservance] = []
        for item in raw {
            if let last = merged.last, item.entry <= last.exit {
                var names = last.names
                for name in item.names where !names.contains(name) { names.append(name) }
                merged[merged.count - 1] = ShabObservance(
                    names: names,
                    entry: min(last.entry, item.entry),
                    exit: max(last.exit, item.exit)
                )
            } else {
                merged.append(item)
            }
        }

        if let next = merged.first(where: { $0.exit > now }) { return next }
        let shabbat = nextShabbat(city, now: now)
        return ShabObservance(
            names: ["שבת"],
            entry: shabbat.candle ?? shabbat.friday,
            exit: shabbat.havdalah ?? shabbat.saturday
        )
    }

    public static func localizedObservanceName(_ name: String, language: String = ShabbatCore.language) -> String {
        if language == "he" { return name }
        let en: [String: String] = [
            "שבת": "Shabbat", "ראש השנה": "Rosh Hashanah", "יום כיפור": "Yom Kippur",
            "סוכות": "Sukkot", "שמיני עצרת": "Shemini Atzeret", "פסח": "Passover", "שבועות": "Shavuot"
        ]
        let fr: [String: String] = [
            "שבת": "Chabbat", "ראש השנה": "Roch Hachana", "יום כיפור": "Yom Kippour",
            "סוכות": "Souccot", "שמיני עצרת": "Chemini Atseret", "פסח": "Pessa'h", "שבועות": "Chavouot"
        ]
        return (language == "fr" ? fr : en)[name] ?? name
    }

    // MARK: - Hebrew calendar helpers

    private struct HolidayRange {
        let name: String
        let first: Date
        let last: Date
    }

    private static func hMod(_ a: Int64, _ b: Int64) -> Int64 { ((a % b) + b) % b }
    private static func gLeap(_ year: Int64) -> Bool { year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) }

    private static func gFix(_ year: Int64, _ month: Int64, _ day: Int64) -> Int64 {
        365 * (year - 1) + (year - 1) / 4 - (year - 1) / 100 + (year - 1) / 400
            + (367 * month - 362) / 12
            + (month <= 2 ? 0 : (gLeap(year) ? -1 : -2)) + day
    }

    private static func gFromFix(_ date: Int64) -> (Int, Int, Int) {
        let d0 = date - 1
        let n400 = d0 / 146097
        let d1 = hMod(d0, 146097)
        let n100 = d1 / 36524
        let d2 = hMod(d1, 36524)
        let n4 = d2 / 1461
        let d3 = hMod(d2, 1461)
        let n1 = d3 / 365
        var year = 400 * n400 + 100 * n100 + 4 * n4 + n1
        if n100 == 4 || n1 == 4 { return (Int(year), 12, 31) }
        year += 1
        let march = gFix(year, 3, 1)
        let correction: Int64 = date < march ? 0 : (gLeap(year) ? 1 : 2)
        let month = (12 * (date - gFix(year, 1, 1) + correction) + 373) / 367
        return (Int(year), Int(month), Int(date - gFix(year, month, 1) + 1))
    }

    private static let hebrewEpoch: Int64 = -1373427
    private static func hLeap(_ year: Int64) -> Bool { hMod(7 * year + 1, 19) < 7 }
    private static func hLastMonth(_ year: Int64) -> Int64 { hLeap(year) ? 13 : 12 }

    private static func hElapsed(_ year: Int64) -> Int64 {
        let months = (235 * year - 234) / 19
        let parts = 12084 + 13753 * months
        let day = months * 29 + parts / 25920
        return hMod(3 * (day + 1), 7) < 3 ? day + 1 : day
    }

    private static func hCorrection(_ year: Int64) -> Int64 {
        let a = hElapsed(year - 1)
        let b = hElapsed(year)
        let c = hElapsed(year + 1)
        if c - b == 356 { return 2 }
        if b - a == 382 { return 1 }
        return 0
    }

    private static func hNewYear(_ year: Int64) -> Int64 { hebrewEpoch + hElapsed(year) + hCorrection(year) }
    private static func hYearLength(_ year: Int64) -> Int64 { hNewYear(year + 1) - hNewYear(year) }

    private static func hMonthLength(_ year: Int64, _ month: Int64) -> Int64 {
        if [2, 4, 6, 10, 13].contains(month) { return 29 }
        if month == 12 && !hLeap(year) { return 29 }
        if month == 8 && ![355, 385].contains(hYearLength(year)) { return 29 }
        if month == 9 && [353, 383].contains(hYearLength(year)) { return 29 }
        return 30
    }

    private static func hFix(_ year: Int64, _ month: Int64, _ day: Int64) -> Int64 {
        var result = hNewYear(year) + day - 1
        if month < 7 {
            if 7 <= hLastMonth(year) {
                for m in 7...hLastMonth(year) { result += hMonthLength(year, m) }
            }
            if month > 1 {
                for m in 1..<month { result += hMonthLength(year, m) }
            }
        } else if month > 7 {
            for m in 7..<month { result += hMonthLength(year, m) }
        }
        return result
    }

    private static func hDate(_ year: Int, _ month: Int, _ day: Int, timeZone: TimeZone) -> Date {
        let g = gFromFix(hFix(Int64(year), Int64(month), Int64(day)))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var dc = DateComponents()
        dc.year = g.0
        dc.month = g.1
        dc.day = g.2
        dc.hour = 12
        return calendar.date(from: dc) ?? Date()
    }

    private static func yomTovDates(_ year: Int, israel: Bool, timeZone: TimeZone) -> [HolidayRange] {
        func range(_ name: String, _ month: Int, _ first: Int, _ last: Int) -> HolidayRange {
            HolidayRange(
                name: name,
                first: hDate(year, month, first, timeZone: timeZone),
                last: hDate(year, month, last, timeZone: timeZone)
            )
        }
        return [
            range("ראש השנה", 7, 1, 2),
            range("יום כיפור", 7, 10, 10),
            range("סוכות", 7, 15, 21),
            range("שמיני עצרת", 7, 22, israel ? 22 : 23),
            range("פסח", 1, 15, israel ? 21 : 22),
            range("שבועות", 3, 6, israel ? 6 : 7)
        ]
    }

    // MARK: - Formatting

    public static func fmt(_ date: Date?, tz: String) -> String {
        guard let date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: tz) ?? .current
        if language == "he" {
            formatter.locale = Locale(identifier: "he_IL")
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "h:mm a"
        }
        return formatter.string(from: date)
    }

    // MARK: - Parasha

    static let parashot: [(Int, String)] = [
        (20260103, "ויחי"), (20260110, "שמות"), (20260117, "וארא"), (20260124, "בא"), (20260131, "בשלח"),
        (20260207, "יתרו"), (20260214, "משפטים"), (20260221, "תרומה"), (20260228, "תצוה"),
        (20260307, "כי תשא"), (20260314, "ויקהל-פקודי"), (20260321, "ויקרא"), (20260328, "צו"),
        (20260411, "שמיני"), (20260418, "תזריע-מצורע"), (20260425, "אחרי מות-קדושים"),
        (20260502, "אמור"), (20260509, "בהר-בחוקותי"), (20260516, "במדבר"), (20260523, "נשא"), (20260530, "בהעלותך"),
        (20260606, "שלח"), (20260613, "קרח"), (20260620, "חוקת"), (20260627, "בלק"),
        (20260704, "פינחס"), (20260711, "מטות-מסעי"), (20260718, "דברים"), (20260725, "ואתחנן"),
        (20260801, "עקב"), (20260808, "ראה"), (20260815, "שופטים"), (20260822, "כי תצא"), (20260829, "כי תבוא"),
        (20260905, "נצבים-וילך"), (20260919, "האזינו"),
        (20261010, "בראשית"), (20261017, "נח"), (20261024, "לך לך"), (20261031, "וירא"),
        (20261107, "חיי שרה"), (20261114, "תולדות"), (20261121, "ויצא"), (20261128, "וישלח"),
        (20261205, "וישב"), (20261212, "מקץ"), (20261219, "ויגש"), (20261226, "ויחי"),
        (20270102, "שמות"), (20270109, "וארא"), (20270116, "בא"), (20270123, "בשלח"), (20270130, "יתרו"),
        (20270206, "משפטים"), (20270213, "תרומה"), (20270220, "תצוה"), (20270227, "כי תשא"),
        (20270306, "ויקהל"), (20270313, "פקודי"), (20270320, "ויקרא"), (20270327, "צו"),
        (20270403, "שמיני"), (20270410, "תזריע"), (20270417, "מצורע"),
        (20270501, "אחרי מות"), (20270508, "קדושים"), (20270515, "אמור"), (20270522, "בהר"), (20270529, "בחוקותי"),
        (20270605, "במדבר"), (20270612, "נשא"), (20270619, "בהעלותך"), (20270626, "שלח"),
        (20270703, "קרח"), (20270710, "חוקת"), (20270717, "בלק"), (20270724, "פינחס"), (20270731, "מטות"),
        (20270807, "מסעי"), (20270814, "דברים"), (20270821, "ואתחנן"), (20270828, "עקב"),
        (20270904, "ראה"), (20270911, "שופטים"), (20270918, "כי תצא"), (20270925, "כי תבוא"),
        (20271009, "נצבים-וילך"), (20271016, "האזינו"), (20271030, "בראשית"),
        (20271106, "נח"), (20271113, "לך לך"), (20271120, "וירא"), (20271127, "חיי שרה"),
        (20271204, "תולדות"), (20271211, "ויצא"), (20271218, "וישלח"), (20271225, "וישב"),
        (20280101, "מקץ"), (20280108, "ויגש"), (20280115, "ויחי"), (20280122, "שמות"), (20280129, "וארא"),
        (20280205, "בא"), (20280212, "בשלח"), (20280219, "יתרו"), (20280226, "משפטים"),
        (20280304, "תרומה"), (20280311, "תצוה"), (20280318, "כי תשא"), (20280325, "ויקהל"),
        (20280401, "פקודי"), (20280408, "ויקרא"), (20280429, "צו"),
        (20280506, "שמיני"), (20280513, "תזריע-מצורע"), (20280520, "אחרי מות-קדושים"), (20280527, "אמור"),
        (20280603, "בהר-בחוקותי"), (20280610, "במדבר"), (20280617, "נשא"), (20280624, "בהעלותך"),
        (20280701, "שלח"), (20280708, "קרח"), (20280715, "חוקת"), (20280722, "בלק"), (20280729, "פינחס"),
        (20280805, "מטות-מסעי"), (20280812, "דברים"), (20280819, "ואתחנן"), (20280826, "עקב"),
        (20280902, "ראה"), (20280909, "שופטים"), (20280916, "כי תצא"), (20280930, "כי תבוא"),
        (20281007, "נצבים"), (20281014, "האזינו"), (20281028, "בראשית"),
        (20281104, "נח"), (20281111, "לך לך"), (20281118, "וירא"), (20281125, "חיי שרה"),
        (20281202, "תולדות"), (20281209, "ויצא"), (20281216, "וישלח"), (20281223, "וישב"), (20281230, "מקץ")
    ]

    public static func parasha(forSaturday saturday: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: loadCity().tz) ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: saturday)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return "" }
        let key = year * 10000 + month * 100 + day
        var best = ""
        for (date, name) in parashot {
            if date <= key { best = name } else { break }
        }
        return best
    }
}
