import UIKit

/// Shares a flattened PNG snapshot of today's drawing with the widget
/// extension via the App Group container. Widgets can't run PencilKit, so
/// the app renders the drawing to an image before handing it over.
enum SharedDrawingStore {
    private static let fileName = "todayDrawing.png"

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedWeatherStore.appGroupID)
    }

    static func save(_ image: UIImage) {
        guard let container = containerURL, let data = image.pngData() else { return }
        try? data.write(to: container.appendingPathComponent(fileName), options: .atomic)
    }

    static func loadImage() -> UIImage? {
        guard let container = containerURL,
              let data = try? Data(contentsOf: container.appendingPathComponent(fileName))
        else { return nil }
        return UIImage(data: data)
    }
}
