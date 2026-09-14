import WidgetKit
import SwiftUI

// ── localization ──────────────────────────────────────────────────────────────
// Widgets must show Hebrew when the device is Hebrew. Resolving strings through
// the widget extension's .lproj bundle proved unreliable (it kept falling back
// to English, and force-unwrapping Bundle(identifier:) risked a crash), so the
// strings live in code and we choose the language from the device's preferred
// languages directly.
private func widgetLanguage() -> String { ShabbatCore.language }
private var widgetDirection: LayoutDirection { widgetLanguage() == "he" ? .rightToLeft : .leftToRight }

private let WSTR_HE: [String: String] = [
    "shabbat.title": "🕯️ שבת",
    "shabbat.candle": "כניסה",
    "shabbat.havdalah": "יציאה",
    "shabbat.config_name": "זמני שבת",
    "shabbat.config_desc": "כניסה ויציאה של השבת או החג הקרובים",
    "netz.title": "🌅 הנץ החמה",
    "netz.config_name": "הנץ החמה",
    "netz.config_desc": "זמן הנץ החמה היום",
    "tzeit.title": "✨ צאת הכוכבים",
    "tzeit.config_name": "צאת הכוכבים",
    "tzeit.config_desc": "זמן צאת הכוכבים היום",
    "sun.title": "☀️ זמני היום",
    "sun.sunrise": "הנץ החמה",
    "sun.nightfall": "צאת הכוכבים",
    "sun.config_name": "הנץ וצאת הכוכבים",
    "sun.config_desc": "הנץ החמה וצאת הכוכבים",
    "parasha.title": "📖 פרשת השבוע",
    "parasha.placeholder": "—",
    "parasha.format": "פרשת %@",
    "parasha.config_name": "פרשת השבוע",
    "parasha.config_desc": "פרשת השבוע הקרובה",
    "tefillin.title": "👉 תפילין היום",
    "tefillin.on": "✅ הנחתי היום",
    "tefillin.off": "☐ עדיין לא הונחו",
    "tefillin.config_name": "הנחת תפילין",
    "tefillin.config_desc": "מעקב הנחת תפילין יומי",
    "combo.config_name": "כל הזמנים",
    "combo.config_desc": "כניסה, יציאה, הנץ וצאת כוכבים",
]
private let WSTR_EN: [String: String] = [
    "shabbat.title": "🕯️ Shabbat",
    "shabbat.candle": "Entry",
    "shabbat.havdalah": "Exit",
    "shabbat.config_name": "Shabbat Times",
    "shabbat.config_desc": "Entry and exit of the next Shabbat or holiday",
    "netz.title": "🌅 Sunrise",
    "netz.config_name": "Sunrise",
    "netz.config_desc": "Sunrise time today",
    "tzeit.title": "✨ Nightfall",
    "tzeit.config_name": "Nightfall",
    "tzeit.config_desc": "Nightfall time today",
    "sun.title": "☀️ Today's times",
    "sun.sunrise": "Sunrise",
    "sun.nightfall": "Nightfall",
    "sun.config_name": "Sun times",
    "sun.config_desc": "Sunrise and nightfall times",
    "parasha.title": "📖 Weekly Parasha",
    "parasha.placeholder": "—",
    "parasha.format": "Parasha %@",
    "parasha.config_name": "Weekly Parasha",
    "parasha.config_desc": "Weekly Torah portion",
    "tefillin.title": "👉 Tefillin today",
    "tefillin.on": "✅ Done today",
    "tefillin.off": "☐ Not yet",
    "tefillin.config_name": "Tefillin",
    "tefillin.config_desc": "Daily tefillin tracking",
    "combo.config_name": "All times",
    "combo.config_desc": "Shabbat, sunrise, and nightfall times",
]
private let WSTR_FR: [String: String] = [
    "shabbat.title": "🕯️ Chabbat", "shabbat.candle": "Entrée", "shabbat.havdalah": "Sortie",
    "shabbat.config_name": "Horaires de Chabbat", "shabbat.config_desc": "Entrée et sortie du prochain Chabbat ou fête",
    "netz.title": "🌅 Lever du soleil", "netz.config_name": "Lever du soleil", "netz.config_desc": "Heure du lever du soleil aujourd’hui",
    "tzeit.title": "✨ Tombée de la nuit", "tzeit.config_name": "Tombée de la nuit", "tzeit.config_desc": "Heure de la tombée de la nuit aujourd’hui",
    "sun.title": "☀️ Horaires du jour", "sun.sunrise": "Lever", "sun.nightfall": "Nuit",
    "sun.config_name": "Horaires solaires", "sun.config_desc": "Lever du soleil et tombée de la nuit",
    "parasha.title": "📖 Paracha de la semaine", "parasha.placeholder": "—", "parasha.format": "Paracha %@",
    "parasha.config_name": "Paracha", "parasha.config_desc": "Paracha de la semaine",
    "tefillin.title": "👉 Téfilines aujourd’hui", "tefillin.on": "✅ Mis aujourd’hui", "tefillin.off": "☐ Pas encore",
    "tefillin.config_name": "Téfilines", "tefillin.config_desc": "Suivi quotidien des téfilines",
    "combo.config_name": "Tous les horaires", "combo.config_desc": "Chabbat, lever du soleil et tombée de la nuit",
]
func wl(_ key: String, _ comment: String = "") -> String {
    let table = widgetLanguage() == "fr" ? WSTR_FR : (widgetLanguage() == "en" ? WSTR_EN : WSTR_HE)
    return table[key] ?? WSTR_HE[key] ?? key
}

extension View {
    func fittedWidgetText() -> some View {
        lineLimit(1).minimumScaleFactor(0.5).allowsTightening(true)
    }
}

// ── shared plumbing ───────────────────────────────────────────────────────────

struct ShabEntry: TimelineEntry { let date: Date }

struct ShabProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShabEntry { ShabEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (ShabEntry) -> Void) {
        completion(ShabEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ShabEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [ShabEntry(date: Date())], policy: .after(next)))
    }
}

let shabBG = Color(red: 0.04, green: 0.06, blue: 0.12)
let goldColor = Color(red: 0.96, green: 0.65, blue: 0.14)
let purpleColor = Color(red: 0.77, green: 0.71, blue: 0.99)
let grayColor = Color(red: 0.48, green: 0.54, blue: 0.62)

/// Fills the widget with the app's navy background. On iOS 17+ (built with
/// Xcode 15+) it uses the modern `containerBackground`; on iOS 15/16 or older
/// Xcode it falls back to a ZStack fill.
struct WidgetBG: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=5.9)
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) { shabBG }
        } else {
            ZStack { shabBG; content }
        }
        #else
        ZStack { shabBG; content }
        #endif
    }
}

// ── 1. כניסת ויציאת שבת ───────────────────────────────────────────────────────

struct ShabbatTimesView: View {
    var body: some View {
        let city = ShabbatCore.loadCity()
        let event = ShabbatCore.nextObservance(city)
        VStack(spacing: 6) {
            Text("🕯️ \(event.localizedTitle()) · \(city.localizedName())").font(.caption2).foregroundColor(grayColor)
            HStack(spacing: 18) {
                VStack(spacing: 2) {
                    Text(wl("shabbat.candle")).font(.caption2).foregroundColor(goldColor)
                    Text(ShabbatCore.fmt(event.entry, tz: city.tz))
                        .font(.title2).bold().foregroundColor(goldColor).fittedWidgetText()
                }
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 40)
                VStack(spacing: 2) {
                    Text(wl("shabbat.havdalah")).font(.caption2).foregroundColor(purpleColor)
                    Text(ShabbatCore.fmt(event.exit, tz: city.tz))
                        .font(.title2).bold().foregroundColor(purpleColor).fittedWidgetText()
                }
            }
        }
        .environment(\.layoutDirection, widgetDirection)
        .modifier(WidgetBG())
    }
}

struct ShabbatTimesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShabbatTimesWidget", provider: ShabProvider()) { entry in
            ShabbatTimesView()
        }
        .configurationDisplayName(wl("shabbat.config_name"))
        .description(wl("shabbat.config_desc"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// ── 2. הנץ החמה ───────────────────────────────────────────────────────────────

struct NetzView: View {
    var body: some View {
        let city = ShabbatCore.loadCity()
        VStack(spacing: 4) {
            Text(wl("netz.title")).font(.caption2).foregroundColor(grayColor)
            Text(ShabbatCore.fmt(ShabbatCore.sunrise(city, ShabbatCore.todayNoon(timeZone: TimeZone(identifier: city.tz) ?? .current)), tz: city.tz))
                .font(.title).bold().foregroundColor(goldColor).fittedWidgetText()
            Text(city.localizedName()).font(.caption2).foregroundColor(grayColor)
        }
        .environment(\.layoutDirection, widgetDirection)
        .modifier(WidgetBG())
    }
}

struct NetzWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NetzWidget", provider: ShabProvider()) { entry in NetzView() }
            .configurationDisplayName(wl("netz.config_name"))
            .description(wl("netz.config_desc"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ── 3. צאת הכוכבים ────────────────────────────────────────────────────────────

struct TzeitView: View {
    var body: some View {
        let city = ShabbatCore.loadCity()
        VStack(spacing: 4) {
            Text(wl("tzeit.title")).font(.caption2).foregroundColor(grayColor)
            Text(ShabbatCore.fmt(ShabbatCore.tzeit(city, ShabbatCore.todayNoon(timeZone: TimeZone(identifier: city.tz) ?? .current)), tz: city.tz))
                .font(.title).bold().foregroundColor(purpleColor).fittedWidgetText()
            Text(city.localizedName()).font(.caption2).foregroundColor(grayColor)
        }
        .environment(\.layoutDirection, widgetDirection)
        .modifier(WidgetBG())
    }
}

struct TzeitWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TzeitWidget", provider: ShabProvider()) { entry in TzeitView() }
            .configurationDisplayName(wl("tzeit.config_name"))
            .description(wl("tzeit.config_desc"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ── 4. הנץ החמה + צאת הכוכבים ────────────────────────────────────────────────

struct SunTimesView: View {
    var body: some View {
        let city = ShabbatCore.loadCity()
        let noon = ShabbatCore.todayNoon(timeZone: TimeZone(identifier: city.tz) ?? .current)
        VStack(spacing: 6) {
            Text("\(wl("sun.title")) · \(city.localizedName())").font(.caption2).foregroundColor(grayColor)
            HStack(spacing: 18) {
                VStack(spacing: 2) {
                    Text(wl("sun.sunrise")).font(.caption2).foregroundColor(goldColor)
                    Text(ShabbatCore.fmt(ShabbatCore.sunrise(city, noon), tz: city.tz))
                        .font(.title2).bold().foregroundColor(goldColor).fittedWidgetText()
                }
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 40)
                VStack(spacing: 2) {
                    Text(wl("sun.nightfall")).font(.caption2).foregroundColor(purpleColor)
                    Text(ShabbatCore.fmt(ShabbatCore.tzeit(city, noon), tz: city.tz))
                        .font(.title2).bold().foregroundColor(purpleColor).fittedWidgetText()
                }
            }
        }
        .environment(\.layoutDirection, widgetDirection)
        .modifier(WidgetBG())
    }
}

struct SunTimesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SunTimesWidget", provider: ShabProvider()) { entry in SunTimesView() }
            .configurationDisplayName(wl("sun.config_name"))
            .description(wl("sun.config_desc"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ── 5. פרשת השבוע ─────────────────────────────────────────────────────────────

struct ParashaView: View {
    var body: some View {
        let city = ShabbatCore.loadCity()
        let t = ShabbatCore.nextShabbat(city)
        let p = ShabbatCore.parasha(forSaturday: t.saturday)
        let placeholder = wl("parasha.placeholder")
        let format = wl("parasha.format")
        VStack(spacing: 4) {
            Text(wl("parasha.title")).font(.caption2).foregroundColor(grayColor)
            Text(p.isEmpty ? placeholder : String(format: format, p))
                .font(.title3).bold().italic().foregroundColor(goldColor)
                .minimumScaleFactor(0.6).lineLimit(1)
        }
        .environment(\.layoutDirection, widgetDirection)
        .modifier(WidgetBG())
    }
}

struct ParashaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ParashaWidget", provider: ShabProvider()) { entry in ParashaView() }
            .configurationDisplayName(wl("parasha.config_name"))
            .description(wl("parasha.config_desc"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ── 6. הנחת תפילין ────────────────────────────────────────────────────────────
// Shows today's status; tapping the widget opens the app to toggle it.
// (Interactive in-widget buttons need iOS 17, so we keep this compatible with
// older devices such as the iPod touch on iOS 15.)

struct TefillinView: View {
    var body: some View {
        let on = ShabbatCore.isTefillinToday()
        let btnText = on ? wl("tefillin.on") : wl("tefillin.off")
        VStack(spacing: 8) {
            Text(wl("tefillin.title")).font(.caption2).foregroundColor(grayColor)
            Text(btnText)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(on ? Color.green.opacity(0.85) : Color.white.opacity(0.1))
                .foregroundColor(on ? .white : grayColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .environment(\.layoutDirection, widgetDirection)
        .modifier(WidgetBG())
    }
}

struct TefillinWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TefillinWidget", provider: ShabProvider()) { entry in TefillinView() }
            .configurationDisplayName(wl("tefillin.config_name"))
            .description(wl("tefillin.config_desc"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ── 7. כניסה + יציאה + הנץ + צאת ────────────────────────────────────────────

struct ComboView: View {
    var body: some View {
        let city = ShabbatCore.loadCity()
        let event = ShabbatCore.nextObservance(city)
        let noon = ShabbatCore.todayNoon(timeZone: TimeZone(identifier: city.tz) ?? .current)
        VStack(spacing: 8) {
            Text("🕯️ \(event.localizedTitle()) · \(city.localizedName())").font(.caption2).foregroundColor(grayColor)
            HStack(spacing: 12) {
                VStack(spacing: 1) {
                    Text(wl("shabbat.candle")).font(.caption2).foregroundColor(goldColor)
                    Text(ShabbatCore.fmt(event.entry, tz: city.tz))
                        .font(.title3).bold().foregroundColor(goldColor).fittedWidgetText()
                }
                Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 30)
                VStack(spacing: 1) {
                    Text(wl("shabbat.havdalah")).font(.caption2).foregroundColor(purpleColor)
                    Text(ShabbatCore.fmt(event.exit, tz: city.tz))
                        .font(.title3).bold().foregroundColor(purpleColor).fittedWidgetText()
                }
                Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 30)
                VStack(spacing: 1) {
                    Text(wl("sun.sunrise")).font(.caption2).foregroundColor(goldColor)
                    Text(ShabbatCore.fmt(ShabbatCore.sunrise(city, noon), tz: city.tz))
                        .font(.title3).bold().foregroundColor(goldColor).fittedWidgetText()
                }
                Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 30)
                VStack(spacing: 1) {
                    Text(wl("sun.nightfall")).font(.caption2).foregroundColor(purpleColor)
                    Text(ShabbatCore.fmt(ShabbatCore.tzeit(city, noon), tz: city.tz))
                        .font(.title3).bold().foregroundColor(purpleColor).fittedWidgetText()
                }
            }
        }
        .environment(\.layoutDirection, widgetDirection)
        .modifier(WidgetBG())
    }
}

struct ComboWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ComboWidget", provider: ShabProvider()) { entry in ComboView() }
            .configurationDisplayName(wl("combo.config_name"))
            .description(wl("combo.config_desc"))
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// ── bundle ────────────────────────────────────────────────────────────────────

@main
struct ShabbatWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ShabbatTimesWidget()
        NetzWidget()
        TzeitWidget()
        SunTimesWidget()
        ParashaWidget()
        TefillinWidget()
        ComboWidget()
    }
}
