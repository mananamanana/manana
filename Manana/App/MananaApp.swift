import SwiftData
import SwiftUI
import UIKit

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
        Self.applyGlobalFontAppearance()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .tint(MananaTheme.accent)
                // A hierarchy-wide default so anything without its own
                // explicit `.font(.manana(...))` — Toggle/TextField labels,
                // Form section headers, etc. — still picks up the custom
                // font instead of falling back to the system one.
                .environment(\.font, .manana(.body))
                .environmentObject(locationManager)
                .environmentObject(weatherService)
                .environmentObject(quoteService)
                .environmentObject(notificationManager)
                .onAppear {
                    notificationManager.requestAuthorization()
                    weatherService.start()
                    quoteService.refresh()
                }
        }
        .modelContainer(for: DiaryEntry.self)
    }

    /// SwiftUI's `.font()` environment value doesn't reach UIKit-backed
    /// chrome — navigation bar titles, segmented controls — so those are
    /// set here via `UIAppearance` to keep the custom font truly everywhere.
    private static func applyGlobalFontAppearance() {
        let titleFont = UIFont(name: "YoonChildfundkoreaMinGuk", size: 17) ?? UIFont.boldSystemFont(ofSize: 17)
        let largeTitleFont = UIFont(name: "YoonChildfundkoreaMinGuk", size: 30) ?? UIFont.boldSystemFont(ofSize: 30)

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.titleTextAttributes = [.font: titleFont]
        navBarAppearance.largeTitleTextAttributes = [.font: largeTitleFont]
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance

        let segmentFont = UIFont(name: "YoonChildfundkoreaDaeHan", size: 14) ?? UIFont.systemFont(ofSize: 14)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: segmentFont], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: segmentFont], for: .selected)
    }
}
