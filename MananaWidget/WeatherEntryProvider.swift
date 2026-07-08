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
            return [Color(hue: 0.58, saturation: 0.12, brightness: 0.82), Color(hue: 0.58, saturation: 0.08, brightness: 0.93)]
        }
        return hsb.map { Color(hue: $0[0], saturation: $0[1], brightness: $0[2]) }
    }
}
