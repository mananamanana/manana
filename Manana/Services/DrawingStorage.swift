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

    static func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
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
        return drawing.image(from: bounds, scale: scale)
    }
}
