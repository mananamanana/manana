import UIKit

/// Shares a flattened PNG snapshot of today's drawing with the widget
/// extension via the App Group container. Widgets can't run PencilKit, so
/// the app renders the drawing to an image before handing it over.
enum SharedDrawingStore {
    private static let fileName = "todayDrawing.png"
    private static let dateKeyDefaultsKey = "todayDrawingDateKey"

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedWeatherStore.appGroupID)
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedWeatherStore.appGroupID)
    }

    /// `dateKey` is always the day the drawing was made on (today, from the
    /// app's perspective). Stored alongside the image so a stale drawing
    /// from a previous day doesn't linger in the widget past midnight — the
    /// app only ever writes here when its own canvas has something on it, so
    /// without this the last non-empty drawing would keep showing until the
    /// app was reopened and drawn on again.
    static func save(_ image: UIImage, dateKey: String) {
        guard let container = containerURL, let data = image.pngData() else { return }
        try? data.write(to: container.appendingPathComponent(fileName), options: .atomic)
        defaults?.set(dateKey, forKey: dateKeyDefaultsKey)
    }

    /// Returns the shared drawing only if it was saved for `dayKey` — a
    /// widget timeline entry for any other day (most commonly "today" once
    /// midnight has passed and the app hasn't been reopened) gets nil, the
    /// same "no drawing yet" state as a day nothing was ever drawn on.
    static func loadImage(forDayKey dayKey: String) -> UIImage? {
        guard defaults?.string(forKey: dateKeyDefaultsKey) == dayKey,
              let container = containerURL,
              let data = try? Data(contentsOf: container.appendingPathComponent(fileName))
        else { return nil }
        return UIImage(data: data)
    }
}
