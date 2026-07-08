import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private var pendingContinuations: [CheckedContinuation<CLLocation, Error>] = []

    enum LocationError: Error {
        case authorizationDenied
        case timedOut
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

    /// Fetches a single fresh location. Does not keep GPS running continuously,
    /// since the app only needs a coarse fix once per weather refresh cycle.
    func requestCurrentLocation() async throws -> CLLocation {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.authorizationDenied
        }
        return try await withCheckedThrowingContinuation { continuation in
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
