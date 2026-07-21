import WidgetKit
import SwiftUI

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
            Text("🕯️ שבת · \(city.name)").font(.caption2).foregroundColor(grayColor)
            HStack(spacing: 18) {
                VStack(spacing: 2) {
                    Text("כניסה").font(.caption2).foregroundColor(goldColor)
                    Text(ShabbatCore.fmt(t.candle, tz: city.tz))
                        .font(.title2).bold().foregroundColor(goldColor)
                }
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 40)
                VStack(spacing: 2) {
                    Text("יציאה").font(.caption2).foregroundColor(purpleColor)
                    Text(ShabbatCore.fmt(t.havdalah, tz: city.tz))
                        .font(.title2).bold().foregroundColor(purpleColor)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .modifier(WidgetBG())
    }
}

struct ShabbatTimesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShabbatTimesWidget", provider: ShabProvider()) { _ in
            ShabbatTimesView()
        }
        .configurationDisplayName("זמני שבת")
        .description("כניסת ויציאת השבת הקרובה")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// ── 2. הנץ החמה ───────────────────────────────────────────────────────────────

struct NetzView: View {
    var body: some View {
        let city = ShabbatCore.loadCity()
        VStack(spacing: 4) {
            Text("🌅 הנץ החמה").font(.caption2).foregroundColor(grayColor)
            Text(ShabbatCore.fmt(ShabbatCore.sunrise(city, ShabbatCore.todayNoon()), tz: city.tz))
                .font(.title).bold().foregroundColor(goldColor)
            Text(city.name).font(.caption2).foregroundColor(grayColor)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .modifier(WidgetBG())
    }
}

struct NetzWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NetzWidget", provider: ShabProvider()) { _ in NetzView() }
            .configurationDisplayName("הנץ החמה")
            .description("זמן הנץ החמה היום")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ── 3. צאת הכוכבים ────────────────────────────────────────────────────────────

struct TzeitView: View {
    var body: some View {
        let city = ShabbatCore.loadCity()
        VStack(spacing: 4) {
            Text("✨ צאת הכוכבים").font(.caption2).foregroundColor(grayColor)
            Text(ShabbatCore.fmt(ShabbatCore.tzeit(city, ShabbatCore.todayNoon()), tz: city.tz))
                .font(.title).bold().foregroundColor(purpleColor)
            Text(city.name).font(.caption2).foregroundColor(grayColor)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .modifier(WidgetBG())
    }
}

struct TzeitWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TzeitWidget", provider: ShabProvider()) { _ in TzeitView() }
            .configurationDisplayName("צאת הכוכבים")
            .description("זמן צאת הכוכבים היום")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ── 4. הנץ החמה + צאת הכוכבים ────────────────────────────────────────────────

struct SunTimesView: View {
    var body: some View {
        let city = ShabbatCore.loadCity()
        let noon = ShabbatCore.todayNoon()
        VStack(spacing: 6) {
            Text("☀️ זמני היום · \(city.name)").font(.caption2).foregroundColor(grayColor)
            HStack(spacing: 18) {
                VStack(spacing: 2) {
                    Text("הנץ החמה").font(.caption2).foregroundColor(goldColor)
                    Text(ShabbatCore.fmt(ShabbatCore.sunrise(city, noon), tz: city.tz))
                        .font(.title2).bold().foregroundColor(goldColor)
                }
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 40)
                VStack(spacing: 2) {
                    Text("צאת הכוכבים").font(.caption2).foregroundColor(purpleColor)
                    Text(ShabbatCore.fmt(ShabbatCore.tzeit(city, noon), tz: city.tz))
                        .font(.title2).bold().foregroundColor(purpleColor)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .modifier(WidgetBG())
    }
}

struct SunTimesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SunTimesWidget", provider: ShabProvider()) { _ in SunTimesView() }
            .configurationDisplayName("הנץ וצאת הכוכבים")
            .description("הנץ החמה וצאת הכוכבים")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ── 5. פרשת השבוע ─────────────────────────────────────────────────────────────

struct ParashaView: View {
    var body: some View {
        let city = ShabbatCore.loadCity()
        let t = ShabbatCore.nextShabbat(city)
        let p = ShabbatCore.parasha(forSaturday: t.saturday)
        VStack(spacing: 4) {
            Text("📖 פרשת השבוע").font(.caption2).foregroundColor(grayColor)
            Text(p.isEmpty ? "—" : "פרשת \(p)")
                .font(.title3).bold().italic().foregroundColor(goldColor)
                .minimumScaleFactor(0.6).lineLimit(1)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .modifier(WidgetBG())
    }
}

struct ParashaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ParashaWidget", provider: ShabProvider()) { _ in ParashaView() }
            .configurationDisplayName("פרשת השבוע")
            .description("פרשת השבוע הקרובה")
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
        VStack(spacing: 8) {
            Text("👉 תפילין היום").font(.caption2).foregroundColor(grayColor)
            Text(on ? "✅ הנחתי היום" : "☐ עדיין לא הונחו")
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
        StaticConfiguration(kind: "TefillinWidget", provider: ShabProvider()) { _ in TefillinView() }
            .configurationDisplayName("הנחת תפילין")
            .description("מעקב הנחת תפילין יומי")
            .supportedFamilies([.systemSmall, .systemMedium])
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
    }
}
