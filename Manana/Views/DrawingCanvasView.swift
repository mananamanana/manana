import PencilKit
import SwiftUI

/// Thin UIViewRepresentable wrapper around PKCanvasView. Pen color and
/// eraser mode are driven from the outside (the expandable tool panel in
/// MainView) rather than fixed here.
struct DrawingCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var canUndo: Bool
    @Binding var canRedo: Bool
    var isErasing: Bool
    var inkColor: UIColor
    /// The day this canvas is currently showing. Captured at the moment a
    /// stroke changes (not at save time) so that if the user swipes to another
    /// day within the save debounce window, the edit still lands on the day it
    /// was actually drawn on rather than whatever day is on screen when the
    /// debounce fires.
    var targetDate: Date
    var onDrawingChanged: (PKDrawing, Date) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        // PencilKit auto-flips pure black/white ink to keep it visible
        // against a dark-mode canvas — without this, picking black in
        // system Dark Mode silently draws white instead (and vice versa).
        // Forcing light style keeps the picked color literal.
        canvasView.overrideUserInterfaceStyle = .light
        canvasView.tool = currentTool
        canvasView.delegate = context.coordinator
        context.coordinator.targetDate = targetDate
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = currentTool
        // Keep the coordinator's notion of "which day" in sync as the home
        // page swipes between days.
        context.coordinator.targetDate = targetDate
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged, canUndo: $canUndo, canRedo: $canRedo, targetDate: targetDate)
    }

    private var currentTool: PKTool {
        isErasing ? PKEraserTool(.bitmap) : PKInkingTool(.crayon, color: inkColor, width: 6)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let onDrawingChanged: (PKDrawing, Date) -> Void
        let canUndo: Binding<Bool>
        let canRedo: Binding<Bool>
        var targetDate: Date
        private var debounceTask: Task<Void, Never>?

        init(onDrawingChanged: @escaping (PKDrawing, Date) -> Void, canUndo: Binding<Bool>, canRedo: Binding<Bool>, targetDate: Date) {
            self.onDrawingChanged = onDrawingChanged
            self.canUndo = canUndo
            self.canRedo = canRedo
            self.targetDate = targetDate
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            canUndo.wrappedValue = canvasView.undoManager?.canUndo ?? false
            canRedo.wrappedValue = canvasView.undoManager?.canRedo ?? false

            let drawing = canvasView.drawing
            // Snapshot the day now, so a later day-swipe can't misroute this save.
            let date = targetDate
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { onDrawingChanged(drawing, date) }
            }
        }
    }
}
