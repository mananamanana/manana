import SwiftUI

/// Coarse weather category used for both background styling and quote tagging.
/// Maps from KMA (기상청) 단기예보 codes: PTY (precipitation type) takes
/// priority since it's directly observed; SKY (cloud cover) only matters
/// when there's no precipitation. KMA's short-term APIs have no distinct
/// fog or thunderstorm code, so those two never occur from this source.
enum WeatherCondition: String, Codable, CaseIterable, Identifiable {
    case clear
    case cloudy
    case fog
    case rain
    case snow
    case thunderstorm

    var id: String { rawValue }

    /// - Parameters:
    ///   - pty: 강수형태 — 0 없음, 1 비, 2 비/눈, 3 눈, 4 소나기, 5 빗방울, 6 빗방울눈날림, 7 눈날림
    ///   - sky: 하늘상태 — 1 맑음, 3 구름많음, 4 흐림 (only consulted when pty == 0)
    static func from(pty: Int, sky: Int?) -> WeatherCondition {
        switch pty {
        case 1, 4, 5:
            return .rain
        case 2, 3, 6, 7:
            return .snow
        default:
            switch sky {
            case 1:
                return .clear
            case 3, 4:
                return .cloudy
            default:
                return .cloudy
            }
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
    ///
    /// Palette follows the "mañana siesta" mood: warm, sun-worn tones (gold,
    /// terracotta, clay) rather than cool blues, even for rain/snow/storms —
    /// unhurried afternoon light rather than clinical weather-app color.
    /// Saturation is kept deliberately restrained (sun-bleached book jacket,
    /// not a vivid weather-app gradient) so it reads as toned paper first,
    /// weather mood second — the daily quote is the thing that should pop.
    func gradientHSB(isDay: Bool) -> [[Double]] {
        switch (self, isDay) {
        case (.clear, true):
            return [[0.11, 0.32, 0.97], [0.04, 0.38, 0.94]]
        case (.clear, false):
            return [[0.80, 0.32, 0.30], [0.03, 0.38, 0.18]]
        case (.cloudy, true):
            return [[0.09, 0.13, 0.91], [0.06, 0.16, 0.85]]
        case (.cloudy, false):
            return [[0.86, 0.14, 0.28], [0.04, 0.18, 0.18]]
        case (.fog, true):
            return [[0.10, 0.06, 0.96], [0.07, 0.07, 0.91]]
        case (.fog, false):
            return [[0.08, 0.07, 0.36], [0.05, 0.08, 0.27]]
        case (.rain, true):
            return [[0.53, 0.14, 0.66], [0.58, 0.20, 0.52]]
        case (.rain, false):
            return [[0.60, 0.20, 0.26], [0.64, 0.23, 0.15]]
        case (.snow, true):
            return [[0.02, 0.07, 0.98], [0.09, 0.07, 1.00]]
        case (.snow, false):
            return [[0.92, 0.11, 0.35], [0.62, 0.09, 0.27]]
        case (.thunderstorm, true):
            return [[0.90, 0.30, 0.46], [0.97, 0.39, 0.31]]
        case (.thunderstorm, false):
            return [[0.92, 0.39, 0.21], [0.99, 0.43, 0.11]]
        }
    }

    func gradientColors(isDay: Bool) -> [Color] {
        gradientHSB(isDay: isDay).map { Color(hue: $0[0], saturation: $0[1], brightness: $0[2]) }
    }

    /// Ink tint for the daily quote — the literary "ink" shifted subtly
    /// toward each condition's mood, so the sentence itself carries a trace
    /// of the day's weather. Raw [red, green, blue] so it can travel to the
    /// widget the same way `gradientHSB` does.
    func quoteInkRGB(isDay: Bool) -> [Double] {
        switch (self, isDay) {
        case (.clear, true):
            return [0.52, 0.32, 0.12]
        case (.clear, false):
            return [0.34, 0.18, 0.30]
        case (.cloudy, true):
            return [0.32, 0.27, 0.23]
        case (.cloudy, false):
            return [0.24, 0.20, 0.19]
        case (.fog, true):
            return [0.36, 0.33, 0.29]
        case (.fog, false):
            return [0.28, 0.26, 0.23]
        case (.rain, true):
            return [0.16, 0.30, 0.32]
        case (.rain, false):
            return [0.13, 0.22, 0.24]
        case (.snow, true):
            return [0.34, 0.24, 0.30]
        case (.snow, false):
            return [0.26, 0.19, 0.24]
        case (.thunderstorm, true):
            return [0.38, 0.12, 0.20]
        case (.thunderstorm, false):
            return [0.26, 0.08, 0.14]
        }
    }

    func quoteInkColor(isDay: Bool) -> Color {
        let rgb = quoteInkRGB(isDay: isDay)
        return Color(red: rgb[0], green: rgb[1], blue: rgb[2])
    }
}

/// Shared visual language for Mañana: a warm, unhurried "siesta" palette —
/// paper, clay, ink — paired with literary serif type for anything quoted
/// and clean rounded type for interface chrome.
/// Hand-illustrated replacement for `Image(systemName:)` — a plain template
/// image so callers can tint and size it exactly like an SF Symbol.
struct WeatherIcon: View {
    let name: String

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
    }
}

enum MananaTheme {
    static let ink = Color(red: 0.24, green: 0.17, blue: 0.14)
    static let paper = Color(red: 0.98, green: 0.94, blue: 0.86)
    static let clay = Color(red: 0.80, green: 0.42, blue: 0.28)
    static let accent = clay
}
