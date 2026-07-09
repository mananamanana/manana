import SwiftUI
import WidgetKit

struct WeatherEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedWeatherSnapshot?
}

/// Shared by all three widgets — they all read the same App Group snapshot,
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

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        let entry = WeatherEntry(date: Date(), snapshot: SharedWeatherStore.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

enum WidgetBackground {
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
