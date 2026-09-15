import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Language

private func widgetLanguage() -> String { ShabbatCore.language }
private var widgetDirection: LayoutDirection { widgetLanguage() == "he" ? .rightToLeft : .leftToRight }

private let WSTR_HE: [String: String] = [
    "shabbat.title": "שבת",
    "shabbat.candle": "כניסה",
    "shabbat.havdalah": "יציאה",
    "shabbat.config_name": "זמני שבת וחג",
    "shabbat.config_desc": "כניסה ויציאה של שבת או החג הקרובים",
    "netz.title": "הנץ החמה",
    "netz.config_name": "הנץ החמה",
    "netz.config_desc": "זמן הנץ החמה היום",
    "tzeit.title": "צאת הכוכבים",
    "tzeit.config_name": "צאת הכוכבים",
    "tzeit.config_desc": "זמן צאת הכוכבים היום",
    "sun.title": "זמני היום",
    "sun.sunrise": "הנץ החמה",
    "sun.nightfall": "צאת הכוכבים",
    "sun.config_name": "הנץ וצאת הכוכבים",
    "sun.config_desc": "הנץ החמה וצאת הכוכבים",
    "parasha.title": "פרשת השבוע",
    "parasha.placeholder": "—",
    "parasha.format": "פרשת %@",
    "parasha.config_name": "פרשת השבוע",
    "parasha.config_desc": "פרשת השבוע הקרובה",
    "tefillin.title": "הנחת תפילין",
    "tefillin.on": "הנחתי היום",
    "tefillin.off": "עדיין לא הנחתי",
    "tefillin.tap": "לחץ לסימון",
    "tefillin.config_name": "הנחת תפילין",
    "tefillin.config_desc": "מעקב הנחת תפילין יומי",
    "combo.config_name": "כל הזמנים",
    "combo.config_desc": "שבת וחג, הנץ וצאת הכוכבים"
]

private let WSTR_EN: [String: String] = [
    "shabbat.title": "Shabbat",
    "shabbat.candle": "Entry",
    "shabbat.havdalah": "Exit",
    "shabbat.config_name": "Shabbat & Holiday Times",
    "shabbat.config_desc": "Upcoming Shabbat or holiday entry and exit",
    "netz.title": "Sunrise",
    "netz.config_name": "Sunrise",
    "netz.config_desc": "Today's sunrise time",
    "tzeit.title": "Nightfall",
    "tzeit.config_name": "Nightfall",
    "tzeit.config_desc": "Today's nightfall time",
    "sun.title": "Today's Times",
    "sun.sunrise": "Sunrise",
    "sun.nightfall": "Nightfall",
    "sun.config_name": "Sun Times",
    "sun.config_desc": "Sunrise and nightfall",
    "parasha.title": "Weekly Parasha",
    "parasha.placeholder": "—",
    "parasha.format": "Parasha %@",
    "parasha.config_name": "Weekly Parasha",
    "parasha.config_desc": "Upcoming weekly Torah portion",
    "tefillin.title": "Tefillin",
    "tefillin.on": "Done today",
    "tefillin.off": "Not done yet",
    "tefillin.tap": "Tap to mark",
    "tefillin.config_name": "Tefillin",
    "tefillin.config_desc": "Daily tefillin tracking",
    "combo.config_name": "All Times",
    "combo.config_desc": "Shabbat, holidays, sunrise and nightfall"
]

private let WSTR_FR: [String: String] = [
    "shabbat.title": "Chabbat",
    "shabbat.candle": "Entrée",
    "shabbat.havdalah": "Sortie",
    "shabbat.config_name": "Horaires Chabbat & fêtes",
    "shabbat.config_desc": "Entrée et sortie du prochain Chabbat ou fête",
    "netz.title": "Lever du soleil",
    "netz.config_name": "Lever du soleil",
    "netz.config_desc": "Heure du lever du soleil aujourd’hui",
    "tzeit.title": "Tombée de la nuit",
    "tzeit.config_name": "Tombée de la nuit",
    "tzeit.config_desc": "Heure de la tombée de la nuit aujourd’hui",
    "sun.title": "Horaires du jour",
    "sun.sunrise": "Lever",
    "sun.nightfall": "Nuit",
    "sun.config_name": "Horaires solaires",
    "sun.config_desc": "Lever du soleil et tombée de la nuit",
    "parasha.title": "Paracha de la semaine",
    "parasha.placeholder": "—",
    "parasha.format": "Paracha %@",
    "parasha.config_name": "Paracha",
    "parasha.config_desc": "Paracha de la semaine",
    "tefillin.title": "Téfilines",
    "tefillin.on": "Mis aujourd’hui",
    "tefillin.off": "Pas encore",
    "tefillin.tap": "Touchez pour marquer",
    "tefillin.config_name": "Téfilines",
    "tefillin.config_desc": "Suivi quotidien des téfilines",
    "combo.config_name": "Tous les horaires",
    "combo.config_desc": "Chabbat, fêtes, lever du soleil et nuit"
]

private func wl(_ key: String) -> String {
    let table = widgetLanguage() == "fr" ? WSTR_FR : (widgetLanguage() == "en" ? WSTR_EN : WSTR_HE)
    return table[key] ?? WSTR_HE[key] ?? key
}

// MARK: - Shared timeline

struct ShabEntry: TimelineEntry {
    let date: Date
}

struct ShabProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShabEntry { ShabEntry(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (ShabEntry) -> Void) {
        completion(ShabEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShabEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [ShabEntry(date: Date())], policy: .after(next)))
    }
}

// MARK: - Shared visual system

private let widgetNavy = Color(red: 0.035, green: 0.055, blue: 0.105)
private let widgetNavy2 = Color(red: 0.07, green: 0.09, blue: 0.18)
private let gold = Color(red: 0.96, green: 0.65, blue: 0.14)
private let purple = Color(red: 0.70, green: 0.62, blue: 0.98)
private let muted = Color.white.opacity(0.58)
private let faint = Color.white.opacity(0.12)

private struct WidgetSurface: ViewModifier {
    func body(content: Content) -> some View {
        let decorated = content
            .padding(14)
            .background(
                LinearGradient(
                    colors: [widgetNavy2, widgetNavy],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

        if #available(iOS 17.0, *) {
            decorated.containerBackground(for: .widget) { widgetNavy }
        } else {
            decorated
        }
    }
}

private extension View {
    func widgetSurface() -> some View {
        modifier(WidgetSurface())
    }

    func oneLine(_ minimum: CGFloat = 0.55) -> some View {
        lineLimit(1)
            .minimumScaleFactor(minimum)
            .allowsTightening(true)
    }
}

private struct WidgetHeader: View {
    let icon: String
    let title: String
    let city: String?

    var body: some View {
        HStack(spacing: 7) {
            Text(icon).font(.system(size: 15))
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.88))
                .oneLine(0.6)
            Spacer(minLength: 4)
            if let city, !city.isEmpty {
                Text(city)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(muted)
                    .oneLine(0.45)
            }
        }
    }
}

private struct TimePill: View {
    let label: String
    let time: String
    let accent: Color
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 3 : 5) {
            Text(label)
                .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
                .foregroundColor(accent.opacity(0.9))
                .oneLine(0.5)
            Text(time)
                .font(.system(size: compact ? 22 : 27, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .oneLine(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 8 : 10)
        .background(accent.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Shabbat / holiday times

struct ShabbatTimesView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let city = ShabbatCore.loadCity()
        let event = ShabbatCore.nextObservance(city)
        let compact = family == .systemSmall

        VStack(alignment: .leading, spacing: compact ? 9 : 12) {
            WidgetHeader(icon: "🕯️", title: event.localizedTitle(), city: city.localizedName())

            if compact {
                VStack(spacing: 7) {
                    TimePill(label: wl("shabbat.candle"), time: ShabbatCore.fmt(event.entry, tz: city.tz), accent: gold, compact: true)
                    TimePill(label: wl("shabbat.havdalah"), time: ShabbatCore.fmt(event.exit, tz: city.tz), accent: purple, compact: true)
                }
            } else {
                HStack(spacing: 10) {
                    TimePill(label: wl("shabbat.candle"), time: ShabbatCore.fmt(event.entry, tz: city.tz), accent: gold, compact: false)
                    TimePill(label: wl("shabbat.havdalah"), time: ShabbatCore.fmt(event.exit, tz: city.tz), accent: purple, compact: false)
                }
            }
        }
        .environment(\.layoutDirection, widgetDirection)
        .widgetSurface()
        .widgetURL(URL(string: "shabbat://open"))
    }
}

struct ShabbatTimesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShabbatTimesWidget", provider: ShabProvider()) { _ in ShabbatTimesView() }
            .configurationDisplayName(wl("shabbat.config_name"))
            .description(wl("shabbat.config_desc"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Sunrise

struct NetzView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let city = ShabbatCore.loadCity()
        let noon = ShabbatCore.todayNoon(timeZone: TimeZone(identifier: city.tz) ?? .current)
        let time = ShabbatCore.fmt(ShabbatCore.sunrise(city, noon), tz: city.tz)

        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(icon: "🌅", title: wl("netz.title"), city: city.localizedName())
            Spacer(minLength: 0)
            Text(time)
                .font(.system(size: family == .systemSmall ? 34 : 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(gold)
                .oneLine(0.6)
            Spacer(minLength: 0)
        }
        .environment(\.layoutDirection, widgetDirection)
        .widgetSurface()
        .widgetURL(URL(string: "shabbat://open"))
    }
}

struct NetzWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NetzWidget", provider: ShabProvider()) { _ in NetzView() }
            .configurationDisplayName(wl("netz.config_name"))
            .description(wl("netz.config_desc"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Nightfall

struct TzeitView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let city = ShabbatCore.loadCity()
        let noon = ShabbatCore.todayNoon(timeZone: TimeZone(identifier: city.tz) ?? .current)
        let time = ShabbatCore.fmt(ShabbatCore.tzeit(city, noon), tz: city.tz)

        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(icon: "✨", title: wl("tzeit.title"), city: city.localizedName())
            Spacer(minLength: 0)
            Text(time)
                .font(.system(size: family == .systemSmall ? 34 : 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(purple)
                .oneLine(0.6)
            Spacer(minLength: 0)
        }
        .environment(\.layoutDirection, widgetDirection)
        .widgetSurface()
        .widgetURL(URL(string: "shabbat://open"))
    }
}

struct TzeitWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TzeitWidget", provider: ShabProvider()) { _ in TzeitView() }
            .configurationDisplayName(wl("tzeit.config_name"))
            .description(wl("tzeit.config_desc"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Sun times

struct SunTimesView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let city = ShabbatCore.loadCity()
        let noon = ShabbatCore.todayNoon(timeZone: TimeZone(identifier: city.tz) ?? .current)
        let sunrise = ShabbatCore.fmt(ShabbatCore.sunrise(city, noon), tz: city.tz)
        let nightfall = ShabbatCore.fmt(ShabbatCore.tzeit(city, noon), tz: city.tz)
        let compact = family == .systemSmall

        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(icon: "☀️", title: wl("sun.title"), city: city.localizedName())
            if compact {
                VStack(spacing: 7) {
                    TimePill(label: wl("sun.sunrise"), time: sunrise, accent: gold, compact: true)
                    TimePill(label: wl("sun.nightfall"), time: nightfall, accent: purple, compact: true)
                }
            } else {
                HStack(spacing: 10) {
                    TimePill(label: wl("sun.sunrise"), time: sunrise, accent: gold, compact: false)
                    TimePill(label: wl("sun.nightfall"), time: nightfall, accent: purple, compact: false)
                }
            }
        }
        .environment(\.layoutDirection, widgetDirection)
        .widgetSurface()
        .widgetURL(URL(string: "shabbat://open"))
    }
}

struct SunTimesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SunTimesWidget", provider: ShabProvider()) { _ in SunTimesView() }
            .configurationDisplayName(wl("sun.config_name"))
            .description(wl("sun.config_desc"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Parasha

struct ParashaView: View {
    var body: some View {
        let city = ShabbatCore.loadCity()
        let t = ShabbatCore.nextShabbat(city)
        let p = ShabbatCore.parasha(forSaturday: t.saturday)
        let text = p.isEmpty ? wl("parasha.placeholder") : String(format: wl("parasha.format"), p)

        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(icon: "📖", title: wl("parasha.title"), city: city.localizedName())
            Spacer(minLength: 0)
            Text(text)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(gold)
                .oneLine(0.45)
            Spacer(minLength: 0)
        }
        .environment(\.layoutDirection, widgetDirection)
        .widgetSurface()
        .widgetURL(URL(string: "shabbat://open"))
    }
}

struct ParashaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ParashaWidget", provider: ShabProvider()) { _ in ParashaView() }
            .configurationDisplayName(wl("parasha.config_name"))
            .description(wl("parasha.config_desc"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Interactive Tefillin

@available(iOS 17.0, *)
struct ToggleTefillinIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Tefillin"
    static var description = IntentDescription("Toggle today's Tefillin status")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        ShabbatCore.toggleTefillinToday()
        WidgetCenter.shared.reloadTimelines(ofKind: "TefillinWidget")
        return .result()
    }
}

private struct TefillinStatusContent: View {
    let on: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(on ? Color.green.opacity(0.22) : Color.white.opacity(0.08))
                    .frame(width: 38, height: 38)
                Image(systemName: on ? "checkmark" : "hand.tap")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(on ? .green : .white.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(on ? wl("tefillin.on") : wl("tefillin.off"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .oneLine(0.55)
                Text(wl("tefillin.tap"))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(muted)
                    .oneLine(0.55)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(on ? Color.green.opacity(0.12) : Color.white.opacity(0.055))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(on ? Color.green.opacity(0.32) : faint, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

struct TefillinView: View {
    var body: some View {
        let on = ShabbatCore.isTefillinToday()

        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(icon: "👉", title: wl("tefillin.title"), city: nil)
            Spacer(minLength: 0)

            if #available(iOS 17.0, *) {
                Button(intent: ToggleTefillinIntent()) {
                    TefillinStatusContent(on: on)
                }
                .buttonStyle(.plain)
            } else {
                Link(destination: URL(string: "shabbat://tefillin")!) {
                    TefillinStatusContent(on: on)
                }
            }

            Spacer(minLength: 0)
        }
        .environment(\.layoutDirection, widgetDirection)
        .widgetSurface()
    }
}

struct TefillinWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TefillinWidget", provider: ShabProvider()) { _ in TefillinView() }
            .configurationDisplayName(wl("tefillin.config_name"))
            .description(wl("tefillin.config_desc"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Combo

struct ComboView: View {
    var body: some View {
        let city = ShabbatCore.loadCity()
        let event = ShabbatCore.nextObservance(city)
        let noon = ShabbatCore.todayNoon(timeZone: TimeZone(identifier: city.tz) ?? .current)

        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(icon: "🕯️", title: event.localizedTitle(), city: city.localizedName())
            HStack(spacing: 8) {
                TimePill(label: wl("shabbat.candle"), time: ShabbatCore.fmt(event.entry, tz: city.tz), accent: gold, compact: true)
                TimePill(label: wl("shabbat.havdalah"), time: ShabbatCore.fmt(event.exit, tz: city.tz), accent: purple, compact: true)
            }
            HStack(spacing: 8) {
                TimePill(label: wl("sun.sunrise"), time: ShabbatCore.fmt(ShabbatCore.sunrise(city, noon), tz: city.tz), accent: gold, compact: true)
                TimePill(label: wl("sun.nightfall"), time: ShabbatCore.fmt(ShabbatCore.tzeit(city, noon), tz: city.tz), accent: purple, compact: true)
            }
        }
        .environment(\.layoutDirection, widgetDirection)
        .widgetSurface()
        .widgetURL(URL(string: "shabbat://open"))
    }
}

struct ComboWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ComboWidget", provider: ShabProvider()) { _ in ComboView() }
            .configurationDisplayName(wl("combo.config_name"))
            .description(wl("combo.config_desc"))
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Bundle

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
