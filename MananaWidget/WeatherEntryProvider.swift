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
        // Return the last saved snapshot (not nil) so that if the system ever
        // falls back to the placeholder — which happened on iPad, leaving the
        // widget looking blank — it still shows real content.
        WeatherEntry(date: Date(), snapshot: SharedWeatherStore.load())
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
        // WidgetKit archives the backing image at its native pixel size and
        // rejects anything over a per-family area limit. The source art is
        // 700×1521 — fine for large/extra-large widgets, but over the small and
        // medium limit, which made those widgets fail to render (blank). This
        // downsamples to a widget-appropriate size so every family archives OK.
        let sized = downsample(image, maxDimension: 500)
        imageCache[name] = sized
        return sized
    }

    /// Redraws `image` so its longest side is at most `maxDimension` points at
    /// scale 1 (so the archived pixel size stays small). Returns the original
    /// if it's already small enough.
    private static func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let ratio = maxDimension / longest
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private static var iconCache: [String: UIImage] = [:]

    /// The hand-drawn weather icon matching the app's own badge. Bundled as a
    /// loose file (like the backgrounds) rather than an asset catalog: the
    /// catalog compiled fine for the simulator but was silently dropped from
    /// the device archive, so on-device the icon never loaded and fell back to
    /// the SF Symbol. The name is derived from the existing `backgroundImageName`
    /// (`background_…` → `weathericon_…`) so no new snapshot field is needed
    /// (which would break decoding of older snapshots). `.iconpng`, not `.png`,
    /// so Xcode's PNG "crush" step leaves the alpha intact. Rendered as a
    /// template image so the caller can tint it; nil → SF Symbol fallback.
    static func icon(for snapshot: SharedWeatherSnapshot?) -> Image? {
        guard let background = snapshot?.backgroundImageName else { return nil }
        let name = background.replacingOccurrences(of: "background_", with: "weathericon_")
        if let cached = iconCache[name] { return Image(uiImage: cached) }
        guard let url = Bundle.main.url(forResource: name, withExtension: "iconpng"),
              let loaded = UIImage(contentsOfFile: url.path)
        else { return nil }
        let image = loaded.withRenderingMode(.alwaysTemplate)
        iconCache[name] = image
        return Image(uiImage: image)
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
