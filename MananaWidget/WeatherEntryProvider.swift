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

    /// Two entries when a same-day precomputed next quote is on hand: "now"
    /// with today's snapshot as-is, and one dated at the next KST midnight
    /// with just its quote fields swapped in. Weather/background carry over
    /// unchanged into that second entry — the real forecast for the new day
    /// isn't known until the app reopens and refreshes, so this only makes
    /// the one thing that *can* be known ahead of time (the quote) flip
    /// exactly on time, entirely on WidgetKit's own clock.
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        let now = Date()
        let snapshot = SharedWeatherStore.load()
        var entries = [WeatherEntry(date: now, snapshot: snapshot)]

        let midnight = SharedWeatherStore.nextMidnight(after: now)
        if var tomorrowSnapshot = snapshot,
           let nextQuote = SharedWeatherStore.loadNextDayQuote(),
           nextQuote.dateKey == SharedWeatherStore.dayKey(midnight) {
            tomorrowSnapshot.quoteText = nextQuote.quoteText
            tomorrowSnapshot.quoteBookTitle = nextQuote.quoteBookTitle
            tomorrowSnapshot.quoteAuthor = nextQuote.quoteAuthor
            entries.append(WeatherEntry(date: midnight, snapshot: tomorrowSnapshot))
        }

        let refreshAnchor = entries.last?.date ?? now
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: refreshAnchor) ?? refreshAnchor.addingTimeInterval(15 * 60)
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
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
