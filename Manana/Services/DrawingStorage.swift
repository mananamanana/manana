import PencilKit
import UIKit

/// Persists each day's PencilKit canvas as raw `.drawing` data on disk, keyed
/// by calendar date, so the canvas can be reloaded and continued later and
/// rendered into a flat image for the archive and share sheet.
final class DrawingStorage {
    static let shared = DrawingStorage()

    private let directory: URL

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = documents.appendingPathComponent("Drawings", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Anchored to KST regardless of the device's own timezone — this app
    /// is Korea-only (KMA weather, Korean UI), and the daily rollover is
    /// meant to follow the Korean calendar day specifically.
    static func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: date)
    }

    func fileName(for date: Date) -> String {
        "\(Self.dateKey(date)).drawing"
    }

    func save(_ drawing: PKDrawing, fileName: String) {
        let url = directory.appendingPathComponent(fileName)
        try? drawing.dataRepresentation().write(to: url, options: .atomic)
    }

    func load(fileName: String) -> PKDrawing {
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url), let drawing = try? PKDrawing(data: data) else {
            return PKDrawing()
        }
        return drawing
    }

    func image(fileName: String, size: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let drawing = load(fileName: fileName)
        guard !drawing.bounds.isEmpty else { return nil }
        let bounds = CGRect(origin: .zero, size: size)
        // PencilKit's pure black/white ink is "adaptive" — it renders
        // according to whatever interface style is current at the moment of
        // rasterization, flipping black to white in Dark Mode, same as the
        // live canvas would without its own `.light` override. Forcing it
        // here keeps every exported image matching what was actually drawn.
        var rendered: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            rendered = drawing.image(from: bounds, scale: scale)
        }
        return rendered
    }

    /// Cropped to just the ink itself rather than the full canvas — a small
    /// doodle drawn in a corner of a much larger canvas would otherwise
    /// render as mostly transparent space around a tiny mark, which reads
    /// as an awkward gap wherever this image gets placed next to other
    /// content (e.g. the archive detail view's drawing-above-quote layout).
    func tightImage(fileName: String, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let drawing = load(fileName: fileName)
        guard !drawing.bounds.isEmpty else { return nil }
        var rendered: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            rendered = drawing.image(from: drawing.bounds, scale: scale)
        }
        return rendered
    }
}
