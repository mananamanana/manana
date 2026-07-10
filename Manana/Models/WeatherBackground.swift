import Foundation

/// The 16 hand-painted background images (Resources/Backgrounds) — a finer
/// weather taxonomy than `WeatherCondition` (which only drives quote
/// tagging/theme colors). Kept as a separate type so quote tagging stays on
/// its existing 6-value system while backgrounds can be this granular.
enum WeatherBackground: String, CaseIterable, Hashable {
    case clearDay = "청명함(낮)"
    case clearNight = "청명함(밤)"
    case partlyCloudyDay = "한때흐림(낮)"
    case partlyCloudyNight = "한때흐림(밤)"
    case overcast = "흐림"
    case rainDay = "비(낮)"
    case rainNight = "비(밤)"
    case heavyRain = "호우"
    case snow = "눈"
    case heavySnow = "폭설"
    case sleet = "눈비"
    case thunderstorm = "뇌우"
    case lightning = "번개"
    case typhoon = "태풍"
    case fog = "안개"
    case mist = "실안개"

    /// Base filename in Resources/Backgrounds, without extension.
    var imageName: String { "background_\(rawValue)" }

    /// The name shown in the compact weather badge — the raw filename's
    /// label with the day/night qualifier dropped, e.g. "비(낮)" → "비".
    var displayLabel: String {
        if let parenIndex = rawValue.firstIndex(of: "(") {
            return String(rawValue[rawValue.startIndex..<parenIndex])
        }
        return rawValue
    }
}

/// The raw KMA signals `WeatherBackground` is derived from — collected
/// across three endpoints (nowcast, village forecast, and the short-term
/// forecast for lightning) since no single one has everything.
struct WeatherBackgroundSignals {
    var pty: Int
    var sky: Int?
    var lightningLevel: Int?
    var precipitationMM: Double?
    var snowCM: Double?
    var windSpeedMS: Double?
    var humidityPercent: Double?
    var isDay: Bool
}

extension WeatherBackground {
    /// Priority order: destructive/rare conditions first (typhoon, lightning,
    /// heavy rain/snow), then ordinary precipitation, then fog/mist (only
    /// guessable from humidity — KMA's short-term APIs have no fog code at
    /// all), then plain sky condition.
    static func from(_ signals: WeatherBackgroundSignals) -> WeatherBackground {
        // Strong sustained wind alongside active precipitation reads as
        // storm-force weather worth calling out visually.
        if let wind = signals.windSpeedMS, wind >= 14, signals.pty != 0 {
            return .typhoon
        }

        if let lightning = signals.lightningLevel, lightning > 0 {
            return signals.pty != 0 ? .thunderstorm : .lightning
        }

        if let mm = signals.precipitationMM, mm >= 30, [1, 4, 5].contains(signals.pty) {
            return .heavyRain
        }
        if let cm = signals.snowCM, cm >= 5, [3, 7].contains(signals.pty) {
            return .heavySnow
        }

        // 2 = 비/눈, 6 = 빗방울눈날림 — both a rain/snow mix.
        if [2, 6].contains(signals.pty) {
            return .sleet
        }
        if [1, 4, 5].contains(signals.pty) {
            return signals.isDay ? .rainDay : .rainNight
        }
        if [3, 7].contains(signals.pty) {
            return .snow
        }

        // No fog/mist code exists in KMA's short-term data — approximate
        // from humidity when there's no precipitation at all.
        if let humidity = signals.humidityPercent {
            if humidity >= 95 { return .fog }
            if humidity >= 88 { return .mist }
        }

        switch signals.sky {
        case 1: return signals.isDay ? .clearDay : .clearNight
        case 3: return signals.isDay ? .partlyCloudyDay : .partlyCloudyNight
        default: return .overcast
        }
    }
}
