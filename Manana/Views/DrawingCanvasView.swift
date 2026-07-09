import PencilKit
import SwiftUI

/// Thin UIViewRepresentable wrapper around PKCanvasView. Kept deliberately
/// single-tool (pen + eraser only, fixed color) to match the very plain,
/// no-chrome canvas the reference app (Grug) uses.
struct DrawingCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var isErasing: Bool
    var onDrawingChanged: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = Self.penTool
        canvasView.delegate = context.coordinator
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = isErasing ? PKEraserTool(.bitmap) : Self.penTool
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }

    /// A soft graphite pencil rather than a heavy pen — thinner, lighter,
    /// closer to the sketchy literary-journal line the app is going for.
    private static var penTool: PKInkingTool {
        PKInkingTool(.pencil, color: UIColor(red: 0.33, green: 0.30, blue: 0.28, alpha: 0.8), width: 3)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let onDrawingChanged: (PKDrawing) -> Void
        private var debounceTask: Task<Void, Never>?

        init(onDrawingChanged: @escaping (PKDrawing) -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let drawing = canvasView.drawing
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { onDrawingChanged(drawing) }
            }
        }
    }
}
