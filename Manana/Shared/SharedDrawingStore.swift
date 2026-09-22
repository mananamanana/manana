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

    /// Removes the shared drawing entirely so the widget shows no drawing —
    /// used when today's canvas has been cleared (erased to empty), which the
    /// normal `save` path skips (it only ever writes non-empty drawings).
    static func clear() {
        if let container = containerURL {
            try? FileManager.default.removeItem(at: container.appendingPathComponent(fileName))
        }
        defaults?.removeObject(forKey: dateKeyDefaultsKey)
    }

    /// Returns the shared drawing only if it was saved for `dayKey` — a
    /// widget timeline entry for any other day (most commonly "today" once
    /// midnight has passed and the app hasn't been reopened) gets nil, the
    /// same "no drawing yet" state as a day nothing was ever drawn on.
    static func loadImage(forDayKey dayKey: String) -> UIImage? {
        guard defaults?.string(forKey: dateKeyDefaultsKey) == dayKey,
              let container = containerURL,
              let data = try? Data(contentsOf: container.appendingPathComponent(fileName)),
              let image = UIImage(data: data)
        else { return nil }
        // Downsample so a big drawing can't push a widget past WidgetKit's image
        // archive-size limit (which made small/medium widgets render blank).
        return downsample(image, maxDimension: 500)
    }

    private static func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let ratio = maxDimension / longest
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
