import WidgetKit
import SwiftUI
import AppIntents

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

struct WidgetBG: ViewModifier {
    func body(content: Content) -> some View {
        content.containerBackground(for: .widget) { shabBG }
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
        .supportedFamilies([.systemSmall, .systemMedium])
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
            .supportedFamilies([.systemSmall])
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
            .supportedFamilies([.systemSmall])
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

// ── 6. הנחת תפילין (כפתור אינטראקטיבי) ───────────────────────────────────────

struct ToggleTefillinIntent: AppIntent {
    static var title: LocalizedStringResource = "הנחת תפילין"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        ShabbatCore.toggleTefillinToday()
        WidgetCenter.shared.reloadTimelines(ofKind: "TefillinWidget")
        return .result()
    }
}

struct TefillinView: View {
    var body: some View {
        let on = ShabbatCore.isTefillinToday()
        VStack(spacing: 8) {
            Text("👉 תפילין היום").font(.caption2).foregroundColor(grayColor)
            Button(intent: ToggleTefillinIntent()) {
                Text(on ? "✅ הנחתי" : "☐ עדיין לא")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(on ? Color.green.opacity(0.85) : Color.white.opacity(0.1))
                    .foregroundColor(on ? .white : grayColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
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
