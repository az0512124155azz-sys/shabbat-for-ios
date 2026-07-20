import Foundation

public struct ShabCity {
    public let name: String
    public let lat: Double
    public let lon: Double
    public let tz: String
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
    public static func saveCity(name: String, lat: Double, lon: Double, tz: String) {
        defaults.set(["n": name, "la": lat, "lo": lon, "tz": tz] as [String: Any], forKey: "city")
    }

    public static func loadCity() -> ShabCity {
        if let d = defaults.dictionary(forKey: "city"),
           let la = d["la"] as? Double, let lo = d["lo"] as? Double {
            return ShabCity(
                name: d["n"] as? String ?? "ירושלים",
                lat: la, lon: lo,
                tz: d["tz"] as? String ?? "Asia/Jerusalem"
            )
        }
        return ShabCity(name: "ירושלים", lat: 31.7683, lon: 35.2137, tz: "Asia/Jerusalem")
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

    public static func sol(lat: Double, lng: Double, day: Date, rising: Bool, zenith: Double) -> Date? {
        let cal = Calendar.current
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
        sol(lat: c.lat, lng: c.lon, day: day, rising: true, zenith: 90.833)
    }
    public static func sunset(_ c: ShabCity, _ day: Date) -> Date? {
        sol(lat: c.lat, lng: c.lon, day: day, rising: false, zenith: 90.833)
    }
    public static func tzeit(_ c: ShabCity, _ day: Date) -> Date? {
        sol(lat: c.lat, lng: c.lon, day: day, rising: false, zenith: 96)
    }
    public static func candle(_ c: ShabCity, friday: Date) -> Date? {
        sunset(c, friday).map { $0.addingTimeInterval(-18 * 60) }
    }
    public static func havdalah(_ c: ShabCity, saturday: Date) -> Date? {
        sunset(c, saturday).map { $0.addingTimeInterval(42 * 60) }
    }

    public static func todayNoon(_ now: Date = Date()) -> Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
    }

    /// Mirrors the friday/saturday selection logic in render() of the HTML.
    public static func nextShabbat(_ city: ShabCity, now: Date = Date()) -> (friday: Date, saturday: Date, candle: Date?, havdalah: Date?) {
        let cal = Calendar.current
        let noon = todayNoon(now)
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
            if let h = havdalah(loadCityIfSame(city), saturday: noon), now < h {
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

    private static func loadCityIfSame(_ c: ShabCity) -> ShabCity { c }

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
        let c = Calendar.current.dateComponents([.year, .month, .day], from: sat)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        let key = y * 10000 + m * 100 + d
        var best = ""
        for (k, name) in parashot {
            if k <= key { best = name } else { break }
        }
        return best
    }
}
