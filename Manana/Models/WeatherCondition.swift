import SwiftUI

/// Coarse weather category used for both background styling and quote tagging.
/// Maps from Open-Meteo's WMO weather codes: https://open-meteo.com/en/docs
enum WeatherCondition: String, Codable, CaseIterable, Identifiable {
    case clear
    case cloudy
    case fog
    case rain
    case snow
    case thunderstorm

    var id: String { rawValue }

    static func from(weatherCode: Int) -> WeatherCondition {
        switch weatherCode {
        case 0, 1:
            return .clear
        case 2, 3:
            return .cloudy
        case 45, 48:
            return .fog
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82:
            return .rain
        case 71, 73, 75, 77, 85, 86:
            return .snow
        case 95, 96, 99:
            return .thunderstorm
        default:
            return .cloudy
        }
    }

    var displayName: String {
        switch self {
        case .clear: return "맑음"
        case .cloudy: return "흐림"
        case .fog: return "안개"
        case .rain: return "비"
        case .snow: return "눈"
        case .thunderstorm: return "천둥번개"
        }
    }

    func emoji(isDay: Bool) -> String {
        switch (self, isDay) {
        case (.clear, true): return "☀️"
        case (.clear, false): return "🌙"
        case (.cloudy, true): return "⛅️"
        case (.cloudy, false): return "☁️"
        case (.fog, _): return "🌫️"
        case (.rain, _): return "🌧️"
        case (.snow, _): return "❄️"
        case (.thunderstorm, _): return "⛈️"
        }
    }

    var symbolName: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .fog: return "cloud.fog.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "snow"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        }
    }

    /// Background gradient stops as raw [hue, saturation, brightness] triples,
    /// tuned separately for day/night. Kept as plain numbers (not `Color`) so
    /// this same data can be written into the widget's shared snapshot.
    func gradientHSB(isDay: Bool) -> [[Double]] {
        switch (self, isDay) {
        case (.clear, true):
            return [[0.56, 0.55, 0.98], [0.12, 0.45, 0.99]]
        case (.clear, false):
            return [[0.68, 0.55, 0.25], [0.72, 0.45, 0.12]]
        case (.cloudy, true):
            return [[0.58, 0.12, 0.82], [0.58, 0.08, 0.93]]
        case (.cloudy, false):
            return [[0.62, 0.15, 0.30], [0.62, 0.10, 0.18]]
        case (.fog, true):
            return [[0.55, 0.05, 0.88], [0.55, 0.03, 0.95]]
        case (.fog, false):
            return [[0.58, 0.08, 0.35], [0.58, 0.05, 0.22]]
        case (.rain, true):
            return [[0.60, 0.35, 0.55], [0.58, 0.25, 0.75]]
        case (.rain, false):
            return [[0.62, 0.40, 0.20], [0.62, 0.30, 0.10]]
        case (.snow, true):
            return [[0.58, 0.10, 0.95], [0.60, 0.05, 1.00]]
        case (.snow, false):
            return [[0.60, 0.15, 0.40], [0.60, 0.08, 0.28]]
        case (.thunderstorm, true):
            return [[0.72, 0.35, 0.40], [0.66, 0.30, 0.55]]
        case (.thunderstorm, false):
            return [[0.74, 0.45, 0.12], [0.70, 0.35, 0.08]]
        }
    }

    func gradientColors(isDay: Bool) -> [Color] {
        gradientHSB(isDay: isDay).map { Color(hue: $0[0], saturation: $0[1], brightness: $0[2]) }
    }
}
