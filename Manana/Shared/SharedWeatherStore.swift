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

/// A single day's quote, keyed by the KST day it belongs to. The main app
/// precomputes a window of these ahead of time and shares them, because the
/// widget extension can't resolve quotes itself (`QuoteService` and the
/// daily-quote sheet it reads aren't part of that target). With a whole
/// window on hand, the widget's timeline can flip to the correct quote at
/// every upcoming midnight entirely on WidgetKit's own clock — even if the
/// app isn't opened for several days.
struct DatedQuote: Codable {
    /// KST day (yyyy-MM-dd) this quote is FOR.
    var dateKey: String
    var quoteText: String
    var quoteBookTitle: String?
    var quoteAuthor: String?
}

enum SharedWeatherStore {
    /// Resolved at runtime so AltStore-rewritten group ids still match — see
    /// `AppGroup`. Was a hardcoded string, which broke widget data sharing
    /// after sideloading.
    static var appGroupID: String { AppGroup.identifier }
    private static let key = "weatherSnapshot"
    private static let upcomingQuotesKey = "upcomingQuotes"

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

    /// The main app's precomputed window of upcoming quotes (today + the next
    /// couple of weeks), keyed by KST day.
    static func saveUpcomingQuotes(_ quotes: [DatedQuote]) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(quotes)
        else { return }
        defaults.set(data, forKey: upcomingQuotesKey)
    }

    static func loadUpcomingQuotes() -> [DatedQuote] {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: upcomingQuotesKey),
              let quotes = try? JSONDecoder().decode([DatedQuote].self, from: data)
        else { return [] }
        return quotes
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

    /// `n` KST days ahead of `date` (keeping the same wall-clock time). Used
    /// by the app to precompute a window of upcoming daily quotes.
    static func date(daysAhead n: Int, from date: Date = Date()) -> Date {
        kstCalendar.date(byAdding: .day, value: n, to: date) ?? date.addingTimeInterval(Double(n) * 86400)
    }
}
