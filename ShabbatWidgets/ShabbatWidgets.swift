import WidgetKit
import SwiftUI

// ── localization helper ───────────────────────────────────────────────────────
private let widgetBundle = Bundle(identifier: "com.tzabary.shabbat.ShabbatWidgets")!
func wl(_ key: String, _ comment: String = "") -> String {
    NSLocalizedString(key, bundle: widgetBundle, comment: comment)
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
        let t = ShabbatCore.nextShabbat(city)
        VStack(spacing: 6) {
            Text("\(wl("shabbat.title")) · \(city.name)").font(.caption2).foregroundColor(grayColor)
            HStack(spacing: 18) {
                VStack(spacing: 2) {
                    Text(wl("shabbat.candle")).font(.caption2).foregroundColor(goldColor)
                    Text(ShabbatCore.fmt(t.candle, tz: city.tz))
                        .font(.title2).bold().foregroundColor(goldColor).frame(minWidth: 60)
                }
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 40)
                VStack(spacing: 2) {
                    Text(wl("shabbat.havdalah")).font(.caption2).foregroundColor(purpleColor)
                    Text(ShabbatCore.fmt(t.havdalah, tz: city.tz))
                        .font(.title2).bold().foregroundColor(purpleColor).frame(minWidth: 60)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
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
            Text(ShabbatCore.fmt(ShabbatCore.sunrise(city, ShabbatCore.todayNoon()), tz: city.tz))
                .font(.title).bold().foregroundColor(goldColor).frame(minWidth: 60)
            Text(city.name).font(.caption2).foregroundColor(grayColor)
        }
        .environment(\.layoutDirection, .rightToLeft)
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
            Text(ShabbatCore.fmt(ShabbatCore.tzeit(city, ShabbatCore.todayNoon()), tz: city.tz))
                .font(.title).bold().foregroundColor(purpleColor).frame(minWidth: 60)
            Text(city.name).font(.caption2).foregroundColor(grayColor)
        }
        .environment(\.layoutDirection, .rightToLeft)
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
        let noon = ShabbatCore.todayNoon()
        VStack(spacing: 6) {
            Text("\(wl("sun.title")) · \(city.name)").font(.caption2).foregroundColor(grayColor)
            HStack(spacing: 18) {
                VStack(spacing: 2) {
                    Text(wl("sun.sunrise")).font(.caption2).foregroundColor(goldColor)
                    Text(ShabbatCore.fmt(ShabbatCore.sunrise(city, noon), tz: city.tz))
                        .font(.title2).bold().foregroundColor(goldColor).frame(minWidth: 60)
                }
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 40)
                VStack(spacing: 2) {
                    Text(wl("sun.nightfall")).font(.caption2).foregroundColor(purpleColor)
                    Text(ShabbatCore.fmt(ShabbatCore.tzeit(city, noon), tz: city.tz))
                        .font(.title2).bold().foregroundColor(purpleColor).frame(minWidth: 60)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
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
        .environment(\.layoutDirection, .rightToLeft)
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
        .environment(\.layoutDirection, .rightToLeft)
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
        let t = ShabbatCore.nextShabbat(city)
        let noon = ShabbatCore.todayNoon()
        VStack(spacing: 8) {
            Text("\(wl("shabbat.title")) · \(city.name)").font(.caption2).foregroundColor(grayColor)
            HStack(spacing: 12) {
                VStack(spacing: 1) {
                    Text(wl("shabbat.candle")).font(.caption2).foregroundColor(goldColor)
                    Text(ShabbatCore.fmt(t.candle, tz: city.tz))
                        .font(.title3).bold().foregroundColor(goldColor).frame(minWidth: 50)
                }
                Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 30)
                VStack(spacing: 1) {
                    Text(wl("shabbat.havdalah")).font(.caption2).foregroundColor(purpleColor)
                    Text(ShabbatCore.fmt(t.havdalah, tz: city.tz))
                        .font(.title3).bold().foregroundColor(purpleColor).frame(minWidth: 50)
                }
                Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 30)
                VStack(spacing: 1) {
                    Text(wl("sun.sunrise")).font(.caption2).foregroundColor(goldColor)
                    Text(ShabbatCore.fmt(ShabbatCore.sunrise(city, noon), tz: city.tz))
                        .font(.title3).bold().foregroundColor(goldColor).frame(minWidth: 50)
                }
                Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 30)
                VStack(spacing: 1) {
                    Text(wl("sun.nightfall")).font(.caption2).foregroundColor(purpleColor)
                    Text(ShabbatCore.fmt(ShabbatCore.tzeit(city, noon), tz: city.tz))
                        .font(.title3).bold().foregroundColor(purpleColor).frame(minWidth: 50)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .modifier(WidgetBG())
    }
}

struct ComboWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ComboWidget", provider: ShabProvider()) { entry in ComboView() }
            .configurationDisplayName(wl("combo.config_name", "All times"))
            .description(wl("combo.config_desc", "Shabbat, sunrise, and nightfall times"))
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
