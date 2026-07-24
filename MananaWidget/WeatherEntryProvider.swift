import SwiftUI
import UIKit
import WidgetKit

struct WeatherEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedWeatherSnapshot?
}

/// Shared by all five widgets — they all read the same App Group snapshot,
/// only the view differs. iOS controls widget refresh cadence for battery
/// reasons, so this can't truly match the in-app 5-minute cycle: it re-reads
/// whatever the app most recently wrote and asks for another look in 15
/// minutes, roughly the shortest interval the system tends to honor.
struct MananaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        completion(WeatherEntry(date: Date(), snapshot: SharedWeatherStore.load()))
    }

    /// One entry per day across the app's precomputed quote window: a "now"
    /// entry for today, then one dated at each upcoming KST midnight with that
    /// day's quote swapped into the last-known snapshot. Weather/background
    /// carry over unchanged — the real forecast for a future day isn't known
    /// until the app reopens — but the *quote* flips exactly on time at every
    /// midnight, entirely on WidgetKit's own clock, so the widget keeps
    /// advancing for the whole window even if the app is never opened. The
    /// quote is always resolved from the window (never left as the snapshot's
    /// own stale field), which is what fixes "still shows yesterday's quote".
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        let now = Date()
        guard let base = SharedWeatherStore.load() else {
            let retry = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
            completion(Timeline(entries: [WeatherEntry(date: now, snapshot: nil)], policy: .after(retry)))
            return
        }

        let upcoming = SharedWeatherStore.loadUpcomingQuotes()
        func snapshot(forDayKey key: String) -> SharedWeatherSnapshot {
            guard let quote = upcoming.first(where: { $0.dateKey == key }) else { return base }
            var snap = base
            snap.quoteText = quote.quoteText
            snap.quoteBookTitle = quote.quoteBookTitle
            snap.quoteAuthor = quote.quoteAuthor
            return snap
        }

        // Today, effective immediately.
        var entries = [WeatherEntry(date: now, snapshot: snapshot(forDayKey: SharedWeatherStore.dayKey(now)))]

        // Each upcoming midnight in the window gets its own entry, so the
        // quote advances day by day with no app involvement.
        var midnight = SharedWeatherStore.nextMidnight(after: now)
        for _ in 0..<14 {
            let key = SharedWeatherStore.dayKey(midnight)
            guard upcoming.contains(where: { $0.dateKey == key }) else { break }
            entries.append(WeatherEntry(date: midnight, snapshot: snapshot(forDayKey: key)))
            midnight = SharedWeatherStore.nextMidnight(after: midnight)
        }

        // `.atEnd` asks WidgetKit for a fresh timeline only once the last
        // entry's day arrives — no premature mid-day refresh that would revert
        // to a stale snapshot before the next midnight.
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

enum WidgetBackground {
    /// Widget-sized copies (MananaWidget/Backgrounds, ~700px wide) of the
    /// same 16 hand-painted backgrounds the main app uses — kept separate
    /// from the app's own full-resolution copies since the widget extension
    /// has a much tighter memory budget.
    private static var imageCache: [String: UIImage] = [:]

    static func image(for snapshot: SharedWeatherSnapshot?) -> UIImage? {
        guard let name = snapshot?.backgroundImageName else { return nil }
        if let cached = imageCache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path)
        else { return nil }
        imageCache[name] = image
        return image
    }

    /// The hand-drawn weather icon matching the app's own badge, loaded from
    /// the widget's WidgetIcons.xcassets. An asset-catalog lookup (not a raw
    /// bundled PNG) so it renders as a proper template image the caller can
    /// tint — returns nil if the asset is missing so the caller can fall back
    /// to the SF Symbol.
    static func icon(for snapshot: SharedWeatherSnapshot?) -> Image? {
        guard let name = snapshot?.weatherIconName, UIImage(named: name) != nil else { return nil }
        return Image(name).renderingMode(.template)
    }

    static func colors(for snapshot: SharedWeatherSnapshot?) -> [Color] {
        guard let hsb = snapshot?.backgroundColors, !hsb.isEmpty else {
            return [Color(hue: 0.09, saturation: 0.18, brightness: 0.90), Color(hue: 0.06, saturation: 0.22, brightness: 0.84)]
        }
        return hsb.map { Color(hue: $0[0], saturation: $0[1], brightness: $0[2]) }
    }

    static func quoteColor(for snapshot: SharedWeatherSnapshot?) -> Color {
        guard let rgb = snapshot?.quoteInkColor, rgb.count == 3 else {
            return Color(red: 0.24, green: 0.17, blue: 0.14)
        }
        return Color(red: rgb[0], green: rgb[1], blue: rgb[2])
    }

    /// The full-bleed widget background — the matching hand-painted art
    /// when available, falling back to the old programmatic gradient
    /// (e.g. for a stale cached snapshot from before this field existed).
    @ViewBuilder
    static func art(for snapshot: SharedWeatherSnapshot?) -> some View {
        if let uiImage = image(for: snapshot) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(colors: colors(for: snapshot), startPoint: .top, endPoint: .bottom)
        }
    }

    static func detailLine(for snapshot: SharedWeatherSnapshot?) -> String? {
        guard let snapshot else { return nil }
        var parts: [String] = []
        if let high = snapshot.highTemp, let low = snapshot.lowTemp {
            parts.append("\(Int(high.rounded()))°/\(Int(low.rounded()))°")
        }
        if let precipitation = snapshot.precipitationProbability {
            parts.append("강수 \(precipitation)%")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
