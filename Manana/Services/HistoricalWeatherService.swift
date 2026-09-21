import Foundation

/// Backfills *past* days' weather from Open-Meteo's free, key-less API, so
/// every recent day can show a real weather background/icon and be drawn on.
///
/// KMA (the live `WeatherService` source) has no historical-observation
/// endpoint accessible with this app's key — a real lookup returned 403, and
/// that endpoint needs its own separate 활용신청 on data.go.kr. Open-Meteo needs
/// no key and returns a whole date range in one request, keyed by day.
enum HistoricalWeatherService {
    struct DayWeather {
        let condition: WeatherCondition
        let temperature: Double?
    }

    private struct Response: Decodable {
        struct Daily: Decodable {
            let time: [String]
            let weatherCode: [Int?]
            let temperatureMax: [Double?]
            let temperatureMin: [Double?]

            enum CodingKeys: String, CodingKey {
                case time
                case weatherCode = "weather_code"
                case temperatureMax = "temperature_2m_max"
                case temperatureMin = "temperature_2m_min"
            }
        }
        let daily: Daily
    }

    /// Fetches up to the last `pastDays` (capped at Open-Meteo's 92-day limit)
    /// of daily weather for the given location, keyed by `DrawingStorage.dateKey`
    /// (yyyy-MM-dd, KST) so the result maps straight onto `DiaryEntry.dayKey`.
    /// Days the source has no code for (it returns null for the oldest slots)
    /// are omitted.
    static func recentDays(latitude: Double, longitude: Double, pastDays: Int = 92) async throws -> [String: DayWeather] {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "Asia/Seoul"),
            URLQueryItem(name: "past_days", value: String(min(max(pastDays, 0), 92))),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let daily = try JSONDecoder().decode(Response.self, from: data).daily

        var result: [String: DayWeather] = [:]
        for (index, day) in daily.time.enumerated() {
            guard index < daily.weatherCode.count, let code = daily.weatherCode[index] else { continue }
            let maxT = index < daily.temperatureMax.count ? daily.temperatureMax[index] : nil
            let minT = index < daily.temperatureMin.count ? daily.temperatureMin[index] : nil
            let temperature: Double?
            if let maxT, let minT {
                temperature = (maxT + minT) / 2
            } else {
                temperature = maxT ?? minT
            }
            result[day] = DayWeather(condition: condition(fromWMO: code), temperature: temperature)
        }
        return result
    }

    /// Maps a WMO weather-interpretation code (Open-Meteo's `weather_code`) to
    /// the app's coarse `WeatherCondition`. Grouped the same way KMA's PTY/SKY
    /// mapping is, so historical days read consistently with live ones.
    static func condition(fromWMO code: Int) -> WeatherCondition {
        switch code {
        case 0, 1: return .clear                                   // clear / mainly clear
        case 2, 3: return .cloudy                                  // partly cloudy / overcast
        case 45, 48: return .fog                                   // fog
        case 51, 53, 55, 56, 57,                                   // drizzle
             61, 63, 65, 66, 67,                                   // rain
             80, 81, 82: return .rain                              // rain showers
        case 71, 73, 75, 77, 85, 86: return .snow                 // snow / snow showers
        case 95, 96, 99: return .thunderstorm                      // thunderstorm
        default: return .cloudy
        }
    }
}
