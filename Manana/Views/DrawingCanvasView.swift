import PencilKit
import SwiftUI

/// Thin UIViewRepresentable wrapper around PKCanvasView. Pen color and
/// eraser mode are driven from the outside (the expandable tool panel in
/// MainView) rather than fixed here.
struct DrawingCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var canUndo: Bool
    var isErasing: Bool
    var inkColor: UIColor
    var onDrawingChanged: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = currentTool
        canvasView.delegate = context.coordinator
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = currentTool
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged, canUndo: $canUndo)
    }

    private var currentTool: PKTool {
        isErasing ? PKEraserTool(.bitmap) : PKInkingTool(.crayon, color: inkColor, width: 6)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let onDrawingChanged: (PKDrawing) -> Void
        let canUndo: Binding<Bool>
        private var debounceTask: Task<Void, Never>?

        init(onDrawingChanged: @escaping (PKDrawing) -> Void, canUndo: Binding<Bool>) {
            self.onDrawingChanged = onDrawingChanged
            self.canUndo = canUndo
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            canUndo.wrappedValue = canvasView.undoManager?.canUndo ?? false

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
