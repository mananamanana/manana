import CoreLocation
import Foundation

/// Polls Open-Meteo (no API key required) for the current weather at the
/// device's location every 5 minutes, keeping the on-screen background in sync.
@MainActor
final class WeatherService: ObservableObject {
    @Published var condition: WeatherCondition = .clear
    @Published var temperature: Double?
    @Published var feelsLike: Double?
    @Published var highTemp: Double?
    @Published var lowTemp: Double?
    @Published var precipitationProbability: Int?
    @Published var isDay: Bool = true
    @Published var lastUpdated: Date?
    @Published var lastError: String?

    static let refreshInterval: TimeInterval = 5 * 60

    private let locationManager: LocationManager
    private var timer: Timer?

    private struct ForecastResponse: Decodable {
        struct CurrentWeather: Decodable {
            let temperature_2m: Double
            let apparent_temperature: Double
            let weather_code: Int
            let is_day: Int
        }
        struct DailyWeather: Decodable {
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
            let precipitation_probability_max: [Int]?
        }
        let current: CurrentWeather
        let daily: DailyWeather
    }

    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }

    func start() {
        locationManager.requestAuthorizationIfNeeded()
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        Task { await fetch() }
    }

    private func fetch() async {
        do {
            let location = try await locationManager.requestCurrentLocation()
            let response = try await fetchForecast(for: location.coordinate)
            condition = .from(weatherCode: response.current.weather_code)
            temperature = response.current.temperature_2m
            feelsLike = response.current.apparent_temperature
            isDay = response.current.is_day == 1
            highTemp = response.daily.temperature_2m_max.first
            lowTemp = response.daily.temperature_2m_min.first
            precipitationProbability = response.daily.precipitation_probability_max?.first
            lastUpdated = Date()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func fetchForecast(for coordinate: CLLocationCoordinate2D) async throws -> ForecastResponse {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(ForecastResponse.self, from: data)
    }
}
