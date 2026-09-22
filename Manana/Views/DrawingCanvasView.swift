import PencilKit
import SwiftUI

/// UIViewRepresentable wrapper around PKCanvasView that owns per-day loading and
/// saving itself.
///
/// The day being shown is passed in as `date`. When it changes, the canvas
/// **flushes the previous day's drawing to disk immediately, then loads the new
/// day's drawing with the change-delegate suppressed**. Nothing outside this
/// view ever assigns `canvasView.drawing` — doing so from the outside used to
/// fire `canvasViewDrawingDidChange`, which then scheduled a save of the
/// just-loaded drawing against the *previous* day, wiping it out (and made a
/// drawing appear to "follow" to the next day). Centralizing it here removes
/// that race entirely.
struct DrawingCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var canUndo: Bool
    @Binding var canRedo: Bool
    var isErasing: Bool
    var inkColor: UIColor
    /// The day currently shown/edited.
    var date: Date
    /// Loads a given day's saved drawing.
    var load: (Date) -> PKDrawing
    /// Persists a drawing for a given day.
    var save: (PKDrawing, Date) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        // PencilKit auto-flips pure black/white ink to keep it visible against a
        // dark-mode canvas — forcing light style keeps the picked color literal.
        canvasView.overrideUserInterfaceStyle = .light
        canvasView.tool = currentTool
        canvasView.delegate = context.coordinator
        context.coordinator.load = load
        context.coordinator.save = save
        context.coordinator.canUndo = $canUndo
        context.coordinator.canRedo = $canRedo
        context.coordinator.switchTo(date: date, canvas: canvasView)
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = currentTool
        // Refresh the closures so saves/loads always see the latest app state.
        context.coordinator.load = load
        context.coordinator.save = save
        context.coordinator.canUndo = $canUndo
        context.coordinator.canRedo = $canRedo
        context.coordinator.switchTo(date: date, canvas: uiView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private var currentTool: PKTool {
        isErasing ? PKEraserTool(.bitmap) : PKInkingTool(.crayon, color: inkColor, width: 6)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var load: ((Date) -> PKDrawing)?
        var save: ((PKDrawing, Date) -> Void)?
        var canUndo: Binding<Bool>?
        var canRedo: Binding<Bool>?

        private var currentDate: Date?
        private var currentDayKey: String?
        /// True while we assign `canvas.drawing` ourselves, so the resulting
        /// delegate callback doesn't schedule a bogus save.
        private var isLoading = false
        private var debounceTask: Task<Void, Never>?

        /// Point the canvas at `date`. Same calendar day → no-op (just refresh
        /// the timestamp). Different day → flush the old day, then load the new.
        func switchTo(date: Date, canvas: PKCanvasView) {
            let key = DrawingStorage.dateKey(date)
            if key == currentDayKey {
                currentDate = date
                return
            }

            // Flush the outgoing day right now. Capture its drawing synchronously
            // (before we overwrite it) but do the actual save on the next tick to
            // avoid mutating model state mid view-update.
            debounceTask?.cancel()
            debounceTask = nil
            if let previous = currentDate, let save {
                let outgoing = canvas.drawing
                DispatchQueue.main.async { save(outgoing, previous) }
            }

            // Load the new day without the assignment counting as a user edit.
            isLoading = true
            canvas.drawing = load?(date) ?? PKDrawing()
            canvas.undoManager?.removeAllActions()
            isLoading = false

            currentDate = date
            currentDayKey = key
            DispatchQueue.main.async {
                self.canUndo?.wrappedValue = false
                self.canRedo?.wrappedValue = false
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            if isLoading { return }

            let cu = canvasView.undoManager?.canUndo ?? false
            let cr = canvasView.undoManager?.canRedo ?? false
            DispatchQueue.main.async {
                self.canUndo?.wrappedValue = cu
                self.canRedo?.wrappedValue = cr
            }

            guard let date = currentDate, let save else { return }
            let drawing = canvasView.drawing
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { save(drawing, date) }
            }
        }
    }
}
