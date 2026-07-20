import Foundation

/// Snapshot of "what the main screen currently shows", written by the app
/// every time the weather refreshes and read by the home screen widget.
/// Colors are stored as raw [hue, saturation, brightness] triples so the
/// widget target doesn't need to depend on WeatherCondition at all.
struct SharedWeatherSnapshot: Codable {
    var emoji: String
    var temperature: Double?
    var feelsLike: Double?
    var highTemp: Double?
    var lowTemp: Double?
    var precipitationProbability: Int?
    var conditionName: String
    var backgroundColors: [[Double]]
    var quoteInkColor: [Double]
    var quoteText: String
    var quoteBookTitle: String?
    var quoteAuthor: String?
    var updatedAt: Date
    /// SF Symbol name — matches the icon shown in-app (`WeatherCondition.symbolName`).
    var symbolName: String = "sun.max.fill"
    /// Base filename (no extension) of the matching hand-painted background
    /// in MananaWidget/Backgrounds — matches `WeatherBackground.imageName`.
    var backgroundImageName: String = "background_청명함(낮)"
}

/// Tomorrow's quote, precomputed and cached by the main app ahead of time.
/// The widget extension can't compute this itself — `QuoteService` and the
/// daily-quote sheet it reads aren't part of that target — so this is the
/// only way a widget's timeline can flip to the right quote exactly at
/// midnight without the app needing to be open right then.
struct NextDayQuote: Codable {
    /// KST day (yyyy-MM-dd) this quote is FOR. Checked against the actual
    /// date before use, so a stale cache (app not opened in a day or more)
    /// gets dropped instead of showing the wrong day's quote.
    var dateKey: String
    var quoteText: String
    var quoteBookTitle: String?
    var quoteAuthor: String?
}

enum SharedWeatherStore {
    static let appGroupID = "group.com.wonji.manana"
    private static let key = "weatherSnapshot"
    private static let nextDayQuoteKey = "nextDayQuote"

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

    static func saveNextDayQuote(_ quote: NextDayQuote) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(quote)
        else { return }
        defaults.set(data, forKey: nextDayQuoteKey)
    }

    static func loadNextDayQuote() -> NextDayQuote? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: nextDayQuoteKey)
        else { return nil }
        return try? JSONDecoder().decode(NextDayQuote.self, from: data)
    }

    // MARK: - KST day math

    /// Anchored to KST regardless of the device's own timezone, matching
    /// every other "what day is it" calculation in this app (see
    /// `DrawingStorage.dateKey`) — both the app's precompute step and the
    /// widget's timeline provider need to agree on exactly when "tomorrow"
    /// starts.
    private static var kstCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }

    static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = kstCalendar
        formatter.timeZone = kstCalendar.timeZone
        return formatter.string(from: date)
    }

    /// The next KST midnight strictly after `date` — used both as "tomorrow"
    /// when precomputing its quote and as the widget timeline entry's date,
    /// so WidgetKit itself swaps the entry in at that exact instant.
    static func nextMidnight(after date: Date = Date()) -> Date {
        let startOfDay = kstCalendar.startOfDay(for: date)
        if startOfDay > date { return startOfDay }
        return kstCalendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date.addingTimeInterval(86400)
    }
}
