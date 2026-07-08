import Foundation

/// Snapshot of "what the main screen currently shows", written by the app
/// every time the weather refreshes and read by the home screen widget.
/// Colors are stored as raw [hue, saturation, brightness] triples so the
/// widget target doesn't need to depend on WeatherCondition at all.
struct SharedWeatherSnapshot: Codable {
    var emoji: String
    var temperature: Double?
    var conditionName: String
    var backgroundColors: [[Double]]
    var quoteText: String
    var quoteSource: String?
    var updatedAt: Date
}

enum SharedWeatherStore {
    static let appGroupID = "group.com.wonji.manana"
    private static let key = "weatherSnapshot"

    static func save(_ snapshot: SharedWeatherSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot)
        else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> SharedWeatherSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: key)
        else { return nil }
        return try? JSONDecoder().decode(SharedWeatherSnapshot.self, from: data)
    }
}
