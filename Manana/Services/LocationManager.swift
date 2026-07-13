import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private var pendingContinuations: [CheckedContinuation<CLLocation, Error>] = []

    enum LocationError: LocalizedError {
        case authorizationDenied
        case timedOut

        var errorDescription: String? {
            switch self {
            case .authorizationDenied:
                return "위치 권한이 꺼져 있어요. 설정 앱에서 허용해주세요."
            case .timedOut:
                return "위치를 확인하지 못했어요. 잠시 후 다시 시도해주세요."
            }
        }
    }

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestAuthorizationIfNeeded() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    /// Fetches a fresh location. Does not keep GPS running continuously,
    /// since the app only needs a coarse fix once per weather refresh cycle.
    ///
    /// `CLLocationManager.requestLocation()` very often fails its *first*
    /// call with a transient `kCLErrorLocationUnknown` — the location
    /// subsystem just hasn't produced a fix yet, not a real failure — and
    /// without a retry here, that single miss left the whole weather
    /// refresh (and the next retry) stuck for a full hour. A few quick
    /// retries covers that instead of surfacing an error immediately.
    func requestCurrentLocation() async throws -> CLLocation {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.authorizationDenied
        }

        for attempt in 0..<3 {
            do {
                return try await singleLocationRequest()
            } catch {
                guard attempt < 2 else { break }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
        // Whatever CLError came back (usually `.locationUnknown`, a
        // transient miss) isn't worth surfacing verbatim — its
        // `localizedDescription` is an unhelpful system string.
        throw LocationError.timedOut
    }

    private func singleLocationRequest() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            pendingContinuations.append(continuation)
            manager.requestLocation()
        }
    }

    private func resumeAll(with result: Result<CLLocation, Error>) {
        let continuations = pendingContinuations
        pendingContinuations.removeAll()
        for continuation in continuations {
            continuation.resume(with: result)
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.resumeAll(with: .success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.resumeAll(with: .failure(error))
        }
    }
}
