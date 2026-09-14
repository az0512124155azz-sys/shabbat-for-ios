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
        names.map { ShabbatCore.localizedObservanceName($0, language: language) }.joined(separator: " + ")
    }
}

/// Native port of the time calculations in shabbat.html.
/// The math must stay identical to the JS version so the app and the
/// widgets/notifications always show the same times.
/// Shared between the app target and the widget extension via an App Group.
public enum ShabbatCore {

    public static let appGroup = "group.com.avishait.shabbat"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    // ── city ──────────────────────────────────────────────────────────────
    public static var language: String {
        get {
            if let saved = defaults.string(forKey: "language"), ["he", "en", "fr"].contains(saved) { return saved }
            let code = Locale.preferredLanguages.first?.lowercased() ?? "he"
            return code.hasPrefix("fr") ? "fr" : (code.hasPrefix("en") ? "en" : "he")
        }
        set {
            guard ["he", "en", "fr"].contains(newValue) else { return }
            // The app and WidgetKit extension read the same App Group value.
            // Keep standard defaults in sync as a fallback for older installs.
            defaults.set(newValue, forKey: "language")
            UserDefaults.standard.set(newValue, forKey: "language")
        }
    }

    public static func saveCity(name: String, nameEn: String = "", nameFr: String = "", lat: Double, lon: Double, tz: String, country: String = "", isGPS: Bool = false) {
        defaults.set(["n": name, "e": nameEn, "f": nameFr, "la": lat, "lo": lon, "tz": tz, "c": country, "gps": isGPS] as [String: Any], forKey: "city")
    }

    public static func loadCity() -> ShabCity {
        if let d = defaults.dictionary(forKey: "city"),
           let la = d["la"] as? Double, let lo = d["lo"] as? Double {
            return ShabCity(
                name: d["n"] as? String ?? "ירושלים",
                nameEn: d["e"] as? String ?? "",
                nameFr: d["f"] as? String ?? "",
                lat: la, lon: lo,
                tz: d["tz"] as? String ?? "Asia/Jerusalem",
                country: d["c"] as? String ?? "",
                isGPS: d["gps"] as? Bool ?? false
            )
        }
        return ShabCity(name: "ירושלים", nameEn: "Jerusalem", nameFr: "Jérusalem", lat: 31.7683, lon: 35.2137, tz: "Asia/Jerusalem", country: "IL", isGPS: false)
    }

    // ── tefillin (date keys are UTC, matching tk() in the HTML) ───────────
    public static func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }

    public static func tefillinMap() -> [String: Bool] {
        (defaults.dictionary(forKey: "tef") as? [String: Bool]) ?? [:]
    }

    public static func isTefillinToday() -> Bool {
        tefillinMap()[todayKey()] ?? false
    }

    public static func setTefillin(_ key: String, _ v: Bool) {
        var m = tefillinMap()
        m[key] = v
        defaults.set(m, forKey: "tef")
    }

    public static func toggleTefillinToday() {
        setTefillin(todayKey(), !isTefillinToday())
    }

    // ── notifications flag ────────────────────────────────────────────────
    public static var notifEnabled: Bool {
        get { defaults.bool(forKey: "notif") }
        set { defaults.set(newValue, forKey: "notif") }
    }

    // ── sun math ──────────────────────────────────────────────────────────
    static func jd(_ y0: Int, _ m0: Int, _ d: Int) -> Double {
        var y = y0, m = m0
        if m <= 2 { y -= 1; m += 12 }
        let a = floor(Double(y) / 100), b = 2 - a + floor(a / 4)
        return floor(365.25 * (Double(y) + 4716)) + floor(30.6001 * Double(m + 1)) + Double(d) + b - 1524.5
    }

    static func jsMod(_ a: Double, _ b: Double) -> Double {
        a.truncatingRemainder(dividingBy: b)
    }

    public static func sol(lat: Double, lng: Double, day: Date, rising: Bool, zenith: Double, timeZone: TimeZone = .current) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: day)
        guard let y = c.year, let mo = c.month, let d = c.day else { return nil }
        let n = jd(y, mo, d) - 2451545 + 0.5
        let L = jsMod(280.46 + 0.9856474 * n, 360)
        let g = jsMod(357.528 + 0.9856003 * n, 360) * .pi / 180
        let lam = (L + 1.915 * sin(g) + 0.02 * sin(2 * g)) * .pi / 180
        let sD = sin(23.439 * .pi / 180) * sin(lam)
        let cD = cos(asin(sD))
        let lR = lat * .pi / 180
        let cosH = (cos(zenith * .pi / 180) - sin(lR) * sD) / (cos(lR) * cD)
        if cosH < -1 || cosH > 1 { return nil }
        var H = acos(cosH) * 180 / .pi
        if rising { H = -H }
        let RA = atan2(cos(23.439 * .pi / 180) * sin(lam), cos(lam)) * 180 / .pi / 15
        let sv = jsMod(jsMod(12 - (L / 15 - jsMod(RA + 360, 24)) - lng / 15 + H / 15, 24) + 24, 24)
        let hh = Int(floor(sv))
        let mm = Int(floor((sv - Double(hh)) * 60))
        let ss = Int(floor(((sv - Double(hh)) * 60 - Double(mm)) * 60))
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        var dc = DateComponents()
        dc.year = y; dc.month = mo; dc.day = d; dc.hour = hh; dc.minute = mm; dc.second = ss
        return utc.date(from: dc)
    }

    public static func sunrise(_ c: ShabCity, _ day: Date) -> Date? {
        sol(lat: c.lat, lng: c.lon, day: day, rising: true, zenith: 90.833, timeZone: TimeZone(identifier: c.tz) ?? .current)
    }
    public static func sunset(_ c: ShabCity, _ day: Date) -> Date? {
        sol(lat: c.lat, lng: c.lon, day: day, rising: false, zenith: 90.833, timeZone: TimeZone(identifier: c.tz) ?? .current)
    }
    public static func tzeit(_ c: ShabCity, _ day: Date) -> Date? {
        sol(lat: c.lat, lng: c.lon, day: day, rising: false, zenith: 96, timeZone: TimeZone(identifier: c.tz) ?? .current)
    }
    private static func candleOffsetMinutes(_ c: ShabCity) -> Double {
        if distanceKm(c.lat, c.lon, 31.7683, 35.2137) <= 15 || [c.name, c.nameEn].contains(where: { $0.lowercased().contains("ירושלים") || $0.lowercased().contains("jerusalem") }) { return 40 }
        if distanceKm(c.lat, c.lon, 32.7940, 34.9896) <= 15 || [c.name, c.nameEn].contains(where: { $0.lowercased().contains("חיפה") || $0.lowercased().contains("haifa") }) { return 30 }
        let country = c.country.lowercased()
        return c.tz == "Asia/Jerusalem" || ["il", "israel", "israël", "ישראל"].contains(country) ? 20 : 18
    }
    private static func distanceKm(_ aLat: Double, _ aLon: Double, _ bLat: Double, _ bLon: Double) -> Double {
        let r = 6371.0, p = Double.pi / 180
        let dLat = (bLat - aLat) * p, dLon = (bLon - aLon) * p
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(aLat * p) * cos(bLat * p) * sin(dLon / 2) * sin(dLon / 2)
        return r * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
    public static func candle(_ c: ShabCity, friday: Date) -> Date? {
        sunset(c, friday).map { $0.addingTimeInterval(-candleOffsetMinutes(c) * 60) }
    }
    // Havdalah = sun 8.5° below horizon ("3 small stars" – matches Hebcal's default motzaei-Shabbat calculation)
    public static func havdalah(_ c: ShabCity, saturday: Date) -> Date? {
        sol(lat: c.lat, lng: c.lon, day: saturday, rising: false, zenith: 98.5, timeZone: TimeZone(identifier: c.tz) ?? .current)
    }

    public static func todayNoon(_ now: Date = Date(), timeZone: TimeZone = .current) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = timeZone
        return cal.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
    }

    /// Mirrors the friday/saturday selection logic in render() of the HTML.
    public static func nextShabbat(_ city: ShabCity, now: Date = Date()) -> (friday: Date, saturday: Date, candle: Date?, havdalah: Date?) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: city.tz) ?? .current
        let noon = todayNoon(now, timeZone: cal.timeZone)
        let dow = cal.component(.weekday, from: now) // 1=Sun ... 6=Fri, 7=Sat

        func nextDow(_ from: Date, _ target: Int) -> Date {
            let d = cal.component(.weekday, from: from)
            var diff = (target - d + 7) % 7
            if diff == 0 { diff = 7 }
            return cal.date(byAdding: .day, value: diff, to: from)!
        }

        var fri: Date
        var sat: Date
        if dow == 7 {
            if let h = havdalah(city, saturday: noon), now < h {
                sat = noon
                fri = cal.date(byAdding: .day, value: -1, to: noon)!
            } else {
                fri = nextDow(noon, 6)
                sat = cal.date(byAdding: .day, value: 1, to: fri)!
            }
        } else if dow == 6 {
            fri = noon
            sat = cal.date(byAdding: .day, value: 1, to: noon)!
        } else {
            fri = nextDow(noon, 6)
            sat = cal.date(byAdding: .day, value: 1, to: fri)!
        }
        return (fri, sat, candle(city, friday: fri), havdalah(city, saturday: sat))
    }

    // MARK: - Upcoming Shabbat / Yom Tov

    /// Returns the nearest active or upcoming sacred period. Overlapping periods
    /// (for example two days of Rosh Hashanah followed by Shabbat) are merged so
    /// notifications and widgets use the final exit time, not Saturday night.
    public static func nextObservance(_ city: ShabCity, now: Date = Date()) -> ShabObservance {
        var raw: [ShabObservance] = []

        // Include enough Shabbatot for notification scheduling and widget refreshes.
        var seenShabbat = Set<Int64>()
        for week in 0..<14 {
            let ref = now.addingTimeInterval(Double(week) * 7 * 86400)
            let s = nextShabbat(city, now: ref)
            if let entry = s.candle, let exit = s.havdalah {
                let key = Int64(entry.timeIntervalSince1970 / 60)
                if seenShabbat.insert(key).inserted {
                    raw.append(ShabObservance(names: ["שבת"], entry: entry, exit: exit))
                }
            }
        }

        let tz = TimeZone(identifier: city.tz) ?? .current
        var gregorian = Calendar(identifier: .gregorian); gregorian.timeZone = tz
        let year = gregorian.component(.year, from: now)
        let israel = city.tz == "Asia/Jerusalem" || ["il", "israel", "israël", "ישראל"].contains(city.country.lowercased())
        for hy in [year + 3759, year + 3760, year + 3761] {
            for holiday in yomTovDates(hebrewYear: hy, israel: israel, timeZone: tz) {
                guard let eve = gregorian.date(byAdding: .day, value: -1, to: holiday.first),
                      let entry = candle(city, friday: eve),
                      let exit = havdalah(city, saturday: holiday.last) else { continue }
                raw.append(ShabObservance(names: [holiday.name], entry: entry, exit: exit))
            }
        }

        raw.sort { $0.entry < $1.entry }
        var merged: [ShabObservance] = []
        for item in raw {
            if let last = merged.last, item.entry <= last.exit {
                let names = last.names + item.names.filter { !last.names.contains($0) }
                merged[merged.count - 1] = ShabObservance(
                    names: names,
                    entry: min(last.entry, item.entry),
                    exit: max(last.exit, item.exit)
                )
            } else {
                merged.append(item)
            }
        }
        if let result = merged.first(where: { $0.exit > now }) { return result }

        // Defensive fallback (the generated list normally always contains one).
        let s = nextShabbat(city, now: now)
        return ShabObservance(names: ["שבת"], entry: s.candle ?? s.friday, exit: s.havdalah ?? s.saturday)
    }

    public static func localizedObservanceName(_ name: String, language: String = ShabbatCore.language) -> String {
        guard language != "he" else { return name }
        let en = [
            "שבת": "Shabbat", "ראש השנה": "Rosh Hashanah", "יום כיפור": "Yom Kippur",
            "סוכות": "Sukkot", "שמיני עצרת": "Shemini Atzeret", "פסח": "Passover", "שבועות": "Shavuot"
        ]
        let fr = [
            "שבת": "Chabbat", "ראש השנה": "Roch Hachana", "יום כיפור": "Yom Kippour",
            "סוכות": "Souccot", "שמיני עצרת": "Chemini Atseret", "פסח": "Pessa'h", "שבועות": "Chavouot"
        ]
        return (language == "fr" ? fr[name] : en[name]) ?? name
    }

    private static func hMod(_ a: Int, _ b: Int) -> Int { ((a % b) + b) % b }
    private static func gLeap(_ y: Int) -> Bool { y % 4 == 0 && (y % 100 != 0 || y % 400 == 0) }
    private static func gFix(_ y: Int, _ m: Int, _ d: Int) -> Int {
        365 * (y - 1) + (y - 1) / 4 - (y - 1) / 100 + (y - 1) / 400
            + (367 * m - 362) / 12 + (m <= 2 ? 0 : (gLeap(y) ? -1 : -2)) + d
    }
    private static func gFromFix(_ date: Int) -> (Int, Int, Int) {
        let d0 = date - 1, n400 = d0 / 146097, d1 = hMod(d0, 146097)
        let n100 = d1 / 36524, d2 = hMod(d1, 36524), n4 = d2 / 1461
        let d3 = hMod(d2, 1461), n1 = d3 / 365
        var year = 400 * n400 + 100 * n100 + 4 * n4 + n1
        if n100 == 4 || n1 == 4 { return (year, 12, 31) }
        year += 1
        let march = gFix(year, 3, 1)
        let correction = date < march ? 0 : (gLeap(year) ? 1 : 2)
        let month = (12 * (date - gFix(year, 1, 1) + correction) + 373) / 367
        return (year, month, date - gFix(year, month, 1) + 1)
    }
    private static let hebrewEpoch = -1373427
    private static func hLeap(_ y: Int) -> Bool { hMod(7 * y + 1, 19) < 7 }
    private static func hLastMonth(_ y: Int) -> Int { hLeap(y) ? 13 : 12 }
    private static func hElapsed(_ y: Int) -> Int {
        let months = (235 * y - 234) / 19, parts = 12084 + 13753 * months
        let day = months * 29 + parts / 25920
        return hMod(3 * (day + 1), 7) < 3 ? day + 1 : day
    }
    private static func hCorrection(_ y: Int) -> Int {
        let a = hElapsed(y - 1), b = hElapsed(y), c = hElapsed(y + 1)
        if c - b == 356 { return 2 }
        if b - a == 382 { return 1 }
        return 0
    }
    private static func hNewYear(_ y: Int) -> Int { hebrewEpoch + hElapsed(y) + hCorrection(y) }
    private static func hYearLength(_ y: Int) -> Int { hNewYear(y + 1) - hNewYear(y) }
    private static func hMonthLength(_ y: Int, _ m: Int) -> Int {
        if [2, 4, 6, 10, 13].contains(m) { return 29 }
        if m == 12 && !hLeap(y) { return 29 }
        if m == 8 && ![355, 385].contains(hYearLength(y)) { return 29 }
        if m == 9 && [353, 383].contains(hYearLength(y)) { return 29 }
        return 30
    }
    private static func hFix(_ y: Int, _ m: Int, _ d: Int) -> Int {
        var result = hNewYear(y) + d - 1
        if m < 7 {
            for month in 7...hLastMonth(y) { result += hMonthLength(y, month) }
            if m > 1 { for month in 1..<m { result += hMonthLength(y, month) } }
        } else if m > 7 {
            for month in 7..<m { result += hMonthLength(y, month) }
        }
        return result
    }
    private static func hDate(_ y: Int, _ m: Int, _ d: Int, timeZone: TimeZone) -> Date {
        let g = gFromFix(hFix(y, m, d))
        var cal = Calendar(identifier: .gregorian); cal.timeZone = timeZone
        return cal.date(from: DateComponents(timeZone: timeZone, year: g.0, month: g.1, day: g.2, hour: 12))!
    }
    private static func yomTovDates(hebrewYear y: Int, israel: Bool, timeZone: TimeZone) -> [(name: String, first: Date, last: Date)] {
        func range(_ name: String, _ month: Int, _ first: Int, _ last: Int) -> (String, Date, Date) {
            (name, hDate(y, month, first, timeZone: timeZone), hDate(y, month, last, timeZone: timeZone))
        }
        return [
            range("ראש השנה", 7, 1, 2), range("יום כיפור", 7, 10, 10),
            range("סוכות", 7, 15, 21), range("שמיני עצרת", 7, 22, israel ? 22 : 23),
            range("פסח", 1, 15, israel ? 21 : 22), range("שבועות", 3, 6, israel ? 6 : 7)
        ]
    }

    public static func fmt(_ d: Date?, tz: String) -> String {
        guard let d = d else { return "--:--" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: tz) ?? .current
        return f.string(from: d)
    }

    // ── parasha (port of the PM table in the HTML) ────────────────────────
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

    public static func parasha(forSaturday sat: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: loadCity().tz) ?? .current
        let c = calendar.dateComponents([.year, .month, .day], from: sat)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        let key = y * 10000 + m * 100 + d
        var best = ""
        for (k, name) in parashot {
            if k <= key { best = name } else { break }
        }
        return best
    }
}
