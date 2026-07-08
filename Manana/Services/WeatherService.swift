import CoreLocation
import Foundation

/// Polls Open-Meteo (no API key required) for the current weather at the
/// device's location every 5 minutes, keeping the on-screen background in sync.
@MainActor
final class WeatherService: ObservableObject {
    @Published var condition: WeatherCondition = .clear
    @Published var temperature: Double?
    @Published var isDay: Bool = true
    @Published var lastUpdated: Date?
    @Published var lastError: String?

    static let refreshInterval: TimeInterval = 5 * 60

    private let locationManager: LocationManager
    private var timer: Timer?

    private struct ForecastResponse: Decodable {
        struct CurrentWeather: Decodable {
            let temperature: Double
            let weathercode: Int
            let is_day: Int
        }
        let current_weather: CurrentWeather
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
            condition = .from(weatherCode: response.current_weather.weathercode)
            temperature = response.current_weather.temperature
            isDay = response.current_weather.is_day == 1
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
            URLQueryItem(name: "current_weather", value: "true"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(ForecastResponse.self, from: data)
    }
}
