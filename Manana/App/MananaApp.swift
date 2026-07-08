import SwiftData
import SwiftUI

@main
struct MananaApp: App {
    @StateObject private var locationManager: LocationManager
    @StateObject private var weatherService: WeatherService
    @StateObject private var quoteService = QuoteService()
    @StateObject private var notificationManager = NotificationManager()

    init() {
        let location = LocationManager()
        _locationManager = StateObject(wrappedValue: location)
        _weatherService = StateObject(wrappedValue: WeatherService(locationManager: location))
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(locationManager)
                .environmentObject(weatherService)
                .environmentObject(quoteService)
                .environmentObject(notificationManager)
                .onAppear {
                    notificationManager.requestAuthorization()
                    weatherService.start()
                }
        }
        .modelContainer(for: DiaryEntry.self)
    }
}
