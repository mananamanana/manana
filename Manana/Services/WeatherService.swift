import CoreLocation
import Foundation

/// Polls the Korea Meteorological Administration (기상청) public forecast
/// API for the current weather at the device's location every hour — that's
/// also KMA's own real-world refresh cadence for these endpoints, so
/// polling faster wouldn't produce fresher data anyway.
///
/// Combines two KMA endpoints because neither alone has everything the UI
/// wants:
///   - 초단기실황 (getUltraSrtNcst): real observed temperature + precipitation
///     type, published hourly at :40.
///   - 단기예보 (getVilageFcst): sky condition, precipitation probability,
///     and today's high/low, published 8x/day.
///
/// Requests go through the `manana-kma-proxy` Cloudflare Worker (see
/// `worker/`) rather than data.go.kr directly — the real service key lives
/// only in that Worker's secret store, not inside this shipped app binary.
struct HourlyForecast: Identifiable {
    let id = UUID()
    let time: Date
    let temperature: Int
    let condition: WeatherCondition

    var hourLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h시"
        return formatter.string(from: time)
    }
}

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
    @Published var locationName: String?
    @Published var hourlyForecast: [HourlyForecast] = []
    @Published var backgroundCondition: WeatherBackground = .clearDay

    static let refreshInterval: TimeInterval = 60 * 60

    private let locationManager: LocationManager
    private var timer: Timer?

    private static let baseURL = "https://manana-kma-proxy.manana-garden.workers.dev"

    private struct KMAResponse: Decodable {
        struct Response: Decodable {
            struct Header: Decodable {
                let resultCode: String
                let resultMsg: String
            }
            struct Body: Decodable {
                struct Items: Decodable {
                    let item: [Item]
                }
                let items: Items
            }
            let header: Header
            let body: Body?
        }
        let response: Response
    }

    private struct Item: Decodable {
        let category: String
        let obsrValue: String?
        let fcstValue: String?
        let fcstDate: String?
        let fcstTime: String?
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

    private func fetch(isRetry: Bool = false) async {
        do {
            let location = try await locationManager.requestCurrentLocation()
            let grid = KMAGrid.nxny(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)

            let ncst = try await fetchItems(path: "getUltraSrtNcst", baseDateTime: nowcastBaseTime(), grid: grid)
            let fcst = try await fetchItems(path: "getVilageFcst", baseDateTime: vilageFcstBaseTime(), grid: grid)

            applyNowcast(ncst)
            applyVilageFcst(fcst)

            // Lightning only comes from this third endpoint — its own
            // failure (e.g. right at a base-time boundary) shouldn't take
            // down the rest of the refresh, so it's isolated here.
            do {
                let shortFcst = try await fetchItems(path: "getUltraSrtFcst", baseDateTime: ultraSrtFcstBaseTime(), grid: grid)
                applyUltraSrtFcst(shortFcst)
            } catch {
                lightningLevel = nil
            }

            isDay = Self.isDaytime()
            lastUpdated = Date()
            lastError = nil

            backgroundCondition = WeatherBackground.from(
                WeatherBackgroundSignals(
                    pty: currentPTY,
                    sky: lastSky,
                    lightningLevel: lightningLevel,
                    precipitationMM: currentPrecipitationMM,
                    snowCM: currentSnowCM,
                    windSpeedMS: currentWindSpeed,
                    humidityPercent: currentHumidity,
                    isDay: isDay
                )
            )

            if let name = await Self.reverseGeocode(location) {
                locationName = name
            }
        } catch {
            // KMA occasionally rejects a request right at its publish-time
            // boundary (e.g. the top-of-hour nowcast isn't live yet) — a
            // single retry a few seconds later almost always succeeds, so
            // this only surfaces to the user if that retry fails too.
            guard !isRetry else {
                lastError = error.localizedDescription
                return
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await fetch(isRetry: true)
        }
    }

    /// Raw signals gathered across all three endpoints, kept only to feed
    /// `WeatherBackground.from(_:)` — `condition`/`temperature` etc. above
    /// remain the UI-facing values.
    private var currentPTY = 0
    private var hasNowcastPTY = false
    private var currentHumidity: Double?
    private var currentWindSpeed: Double?
    private var currentPrecipitationMM: Double?
    private var currentSnowCM: Double?
    private var lightningLevel: Int?

    private func applyNowcast(_ items: [Item]) {
        var pty: Int?
        for item in items {
            switch item.category {
            case "T1H":
                temperature = item.obsrValue.flatMap(Double.init)
            case "PTY":
                pty = item.obsrValue.flatMap(Int.init)
            case "REH":
                currentHumidity = item.obsrValue.flatMap(Double.init)
            case "WSD":
                currentWindSpeed = item.obsrValue.flatMap(Double.init)
            case "RN1":
                currentPrecipitationMM = item.obsrValue.flatMap(Double.init)
            default:
                break
            }
        }
        if let pty {
            currentPTY = pty
            hasNowcastPTY = true
            condition = WeatherCondition.from(pty: pty, sky: lastSky)
        }
    }

    /// Cached separately since PTY (nowcast) and SKY (forecast) come from
    /// two different responses that don't always agree on which "now" they
    /// describe.
    private var lastSky: Int?

    private struct HourlyBuilder {
        var temperature: Int?
        var sky: Int?
        var pty: Int?
    }

    private func applyVilageFcst(_ items: [Item]) {
        let today = Self.dateFormatter.string(from: Date())
        var nearestSky: (time: String, value: Int)?
        var nearestPop: (time: String, value: Int)?
        var nearestWSD: (time: String, value: Double)?
        var nearestREH: (time: String, value: Double)?
        var nearestPCP: (time: String, value: String)?
        var nearestSNO: (time: String, value: String)?
        var pty: Int?
        var hourlyBuilders: [String: HourlyBuilder] = [:]

        for item in items {
            guard let fcstTime = item.fcstTime, let fcstDate = item.fcstDate else { continue }
            let hourKey = fcstDate + fcstTime
            switch item.category {
            case "SKY":
                if let value = item.fcstValue.flatMap(Int.init) {
                    if nearestSky == nil || fcstTime < nearestSky!.time { nearestSky = (fcstTime, value) }
                    hourlyBuilders[hourKey, default: HourlyBuilder()].sky = value
                }
            case "POP":
                if let value = item.fcstValue.flatMap(Int.init), nearestPop == nil || fcstTime < nearestPop!.time {
                    nearestPop = (fcstTime, value)
                }
            case "PTY":
                if let value = item.fcstValue.flatMap(Int.init) {
                    if pty == nil { pty = value }
                    hourlyBuilders[hourKey, default: HourlyBuilder()].pty = value
                }
            case "TMP":
                if let value = item.fcstValue.flatMap(Double.init) {
                    hourlyBuilders[hourKey, default: HourlyBuilder()].temperature = Int(value.rounded())
                }
            case "TMX":
                if fcstDate == today { highTemp = item.fcstValue.flatMap(Double.init) }
            case "TMN":
                if fcstDate == today { lowTemp = item.fcstValue.flatMap(Double.init) }
            case "WSD":
                if let value = item.fcstValue.flatMap(Double.init), nearestWSD == nil || fcstTime < nearestWSD!.time {
                    nearestWSD = (fcstTime, value)
                }
            case "REH":
                if let value = item.fcstValue.flatMap(Double.init), nearestREH == nil || fcstTime < nearestREH!.time {
                    nearestREH = (fcstTime, value)
                }
            case "PCP":
                if let value = item.fcstValue, nearestPCP == nil || fcstTime < nearestPCP!.time {
                    nearestPCP = (fcstTime, value)
                }
            case "SNO":
                if let value = item.fcstValue, nearestSNO == nil || fcstTime < nearestSNO!.time {
                    nearestSNO = (fcstTime, value)
                }
            default:
                break
            }
        }

        lastSky = nearestSky?.value
        precipitationProbability = nearestPop?.value

        // Nowcast's real-time PTY/humidity/wind win when present; the
        // forecast's bucketed PCP/SNO amounts still feed in as an upper
        // bound for heavy-rain/snow detection either way.
        if !hasNowcastPTY, let pty {
            currentPTY = pty
        }
        if currentHumidity == nil, let reh = nearestREH?.value {
            currentHumidity = reh
        }
        if let wsd = nearestWSD?.value {
            currentWindSpeed = max(currentWindSpeed ?? 0, wsd)
        }
        if let pcpText = nearestPCP?.value, let mm = Self.leadingNumber(in: pcpText) {
            currentPrecipitationMM = max(currentPrecipitationMM ?? 0, mm)
        }
        if let snoText = nearestSNO?.value, let cm = Self.leadingNumber(in: snoText) {
            currentSnowCM = max(currentSnowCM ?? 0, cm)
        }

        // Nowcast's own PTY already drove `condition` in applyNowcast; only
        // fall back to the forecast's SKY/PTY here if nowcast had nothing.
        if temperature == nil, let pty {
            condition = WeatherCondition.from(pty: pty, sky: lastSky)
        } else if let sky = lastSky, let pty {
            condition = WeatherCondition.from(pty: pty, sky: sky)
        }

        let now = Date()
        hourlyForecast = Array(
            hourlyBuilders
                .compactMap { key, builder -> HourlyForecast? in
                    guard let temperature = builder.temperature,
                          let sky = builder.sky,
                          let time = Self.hourlyDateFormatter.date(from: key)
                    else { return nil }
                    return HourlyForecast(
                        time: time,
                        temperature: temperature,
                        condition: WeatherCondition.from(pty: builder.pty ?? 0, sky: sky)
                    )
                }
                .filter { $0.time > now }
                .sorted { $0.time < $1.time }
                .prefix(6)
        )
    }

    /// 초단기예보's LGT (낙뢰/lightning) is the only source for thunderstorm
    /// backgrounds — nowcast and the village forecast have no such category.
    /// Any value above 0 means lightning activity is forecast that hour.
    private func applyUltraSrtFcst(_ items: [Item]) {
        var nearest: (time: String, value: Int)?
        for item in items where item.category == "LGT" {
            guard let fcstTime = item.fcstTime, let value = item.fcstValue.flatMap(Int.init) else { continue }
            if nearest == nil || fcstTime < nearest!.time {
                nearest = (fcstTime, value)
            }
        }
        lightningLevel = nearest?.value
    }

    /// KMA's PCP/SNO fields are bucketed strings ("1mm 미만", "30~50mm",
    /// "강수없음"...) rather than plain numbers — this pulls out the first
    /// number in the string as a usable lower-bound estimate.
    private static func leadingNumber(in text: String) -> Double? {
        var digits = ""
        for character in text {
            if character.isNumber || character == "." {
                digits.append(character)
            } else if !digits.isEmpty {
                break
            }
        }
        return Double(digits)
    }

    /// Reverse-geocodes to a Korean administrative area name (e.g. "서울특별시")
    /// for display in the expanded weather box — KMA's own API has no such
    /// name, only grid coordinates.
    private static func reverseGeocode(_ location: CLLocation) async -> String? {
        await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ko_KR")) { placemarks, _ in
                let placemark = placemarks?.first
                continuation.resume(returning: placemark?.administrativeArea ?? placemark?.locality)
            }
        }
    }

    private func fetchItems(path: String, baseDateTime: (date: String, time: String), grid: (nx: Int, ny: Int)) async throws -> [Item] {
        var components = URLComponents(string: "\(Self.baseURL)/\(path)")!
        components.queryItems = [
            URLQueryItem(name: "pageNo", value: "1"),
            URLQueryItem(name: "numOfRows", value: "100"),
            URLQueryItem(name: "dataType", value: "JSON"),
            URLQueryItem(name: "base_date", value: baseDateTime.date),
            URLQueryItem(name: "base_time", value: baseDateTime.time),
            URLQueryItem(name: "nx", value: String(grid.nx)),
            URLQueryItem(name: "ny", value: String(grid.ny)),
        ]
        // The Worker injects the real serviceKey server-side — the client
        // never holds or sends one.
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(KMAResponse.self, from: data)
        guard decoded.response.header.resultCode == "00" else {
            throw WeatherServiceError.api(decoded.response.header.resultMsg)
        }
        return decoded.response.body?.items.item ?? []
    }

    enum WeatherServiceError: LocalizedError {
        case api(String)
        var errorDescription: String? {
            switch self {
            case .api(let message): return "기상청 API 오류: \(message)"
            }
        }
    }

    /// 초단기실황 is generated hourly at :40 for the base_time equal to that
    /// hour (format HH00), and isn't queryable until then — so before :40
    /// past the hour, the latest usable base_time is still the previous hour.
    private func nowcastBaseTime() -> (date: String, time: String) {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        var now = Date()
        let minute = calendar.component(.minute, from: now)
        if minute < 40 {
            now = calendar.date(byAdding: .hour, value: -1, to: now) ?? now
        }
        let hour = calendar.component(.hour, from: now)
        return (Self.dateFormatter.string(from: now), String(format: "%02d00", hour))
    }

    /// 단기예보(getVilageFcst) is issued 8x/day at 02/05/08/11/14/17/20/23,
    /// each available a little after the hour — use the most recent one
    /// with a safety buffer.
    private func vilageFcstBaseTime() -> (date: String, time: String) {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let issueHours = [23, 20, 17, 14, 11, 8, 5, 2]
        var now = Date()
        now = calendar.date(byAdding: .minute, value: -15, to: now) ?? now
        let hour = calendar.component(.hour, from: now)

        for issueHour in issueHours where issueHour <= hour {
            return (Self.dateFormatter.string(from: now), String(format: "%02d00", issueHour))
        }
        // Before 02:15 local time: fall back to yesterday's 23:00 issue.
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        return (Self.dateFormatter.string(from: yesterday), "2300")
    }

    /// 초단기예보(getUltraSrtFcst) is issued hourly at :30, available from
    /// :45 — same shape as the nowcast's :40 rule but offset by 30 minutes.
    private func ultraSrtFcstBaseTime() -> (date: String, time: String) {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        var now = Date()
        let minute = calendar.component(.minute, from: now)
        if minute < 45 {
            now = calendar.date(byAdding: .hour, value: -1, to: now) ?? now
        }
        let hour = calendar.component(.hour, from: now)
        return (Self.dateFormatter.string(from: now), String(format: "%02d30", hour))
    }

    private static func isDaytime(reference: Date = Date()) -> Bool {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let hour = calendar.component(.hour, from: reference)
        return (6..<19).contains(hour)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()

    private static let hourlyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()
}
