import PencilKit
import SwiftUI
import WidgetKit

/// Editable canvas for a *past* diary entry's drawing, opened from the entry
/// detail view's pencil button. The main screen only lets you draw on today;
/// this gives past days the same pen/eraser/undo tools, loading that day's
/// saved drawing and writing changes back to the same day's storage. The
/// widget only ever tracks today, so editing a past day leaves it untouched —
/// but editing today's entry through here still keeps the widget in sync.
struct DiaryEntryEditView: View {
    let entry: DiaryEntry
    /// Called after each save so the detail view can re-read the drawing.
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var canvasView = PKCanvasView()
    @State private var isErasing = false
    @State private var selectedColor: Color = .black
    @State private var showColorPicker = false
    @State private var canUndo = false
    @State private var canRedo = false
    // Triple-tapping the eraser clears the whole drawing, same as the main screen.
    @State private var eraserTapCount = 0
    @State private var lastEraserTapAt = Date.distantPast

    private static let paletteColors: [Color] = [.black, .red, .yellow, .green, .blue, .white]
    private static var backgroundCache: [WeatherBackground: UIImage] = [:]

    private var background: WeatherBackground {
        WeatherBackground(condition: entry.weatherCondition)
    }

    private var isToday: Bool {
        DrawingStorage.dateKey(entry.date) == DrawingStorage.dateKey(Date())
    }

    var body: some View {
        ZStack {
            backgroundArt
                .ignoresSafeArea()

            DrawingCanvasView(
                canvasView: $canvasView,
                canUndo: $canUndo,
                canRedo: $canRedo,
                isErasing: isErasing,
                inkColor: UIColor(selectedColor)
            ) { drawing in
                persist(drawing)
            }
            .ignoresSafeArea()

            // 완료 button, top-left, kept inside the safe area.
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("완료")
                            .font(.manana(size: 18, weight: .semibold))
                            .foregroundStyle(MananaTheme.ink)
                            .shadow(color: MananaTheme.paper.opacity(0.6), radius: 2, y: 1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Spacer()
            }

            // Drawing tools, bottom-right, same look as the main screen.
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    toolPanel
                        .padding(.trailing, 20)
                        .padding(.bottom, 40)
                }
            }
        }
        .onAppear(perform: loadDrawing)
    }

    private var toolPanel: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if showColorPicker {
                VStack(spacing: 6) {
                    ForEach(Self.paletteColors, id: \.self) { color in
                        Button {
                            selectedColor = color
                            isErasing = false
                        } label: {
                            Image(paletteCrayonImageName(for: color))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .background(
                                    Circle()
                                        .strokeBorder(MananaTheme.ink.opacity(0.15), lineWidth: 1)
                                        .padding(-2)
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(MananaTheme.clay, lineWidth: 2)
                                        .padding(-4)
                                        .opacity(!isErasing && selectedColor == color ? 1 : 0)
                                )
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))

                Rectangle()
                    .fill(MananaTheme.ink.opacity(0.12))
                    .frame(width: 20, height: 1)
            }

            toolButton("IconPen", isActive: !isErasing, tint: selectedColor == .white ? nil : selectedColor) {
                eraserTapCount = 0
                isErasing = false
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    showColorPicker.toggle()
                }
            }

            toolButton("IconEraser", isActive: isErasing) {
                handleEraserTap()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    showColorPicker = false
                }
            }

            toolButton("IconUndo", isActive: false) {
                canvasView.undoManager?.undo()
            }
            .disabled(!canUndo)
            .opacity(canUndo ? 1 : 0.35)

            toolButton("IconRedo", isActive: false) {
                canvasView.undoManager?.redo()
            }
            .disabled(!canRedo)
            .opacity(canRedo ? 1 : 0.35)
        }
    }

    private func toolButton(_ imageName: String, isActive: Bool, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .renderingMode(tint == nil ? .original : .template)
                .scaledToFit()
                .frame(width: 30, height: 30)
                .frame(width: 40, height: 40)
                .foregroundStyle(tint ?? MananaTheme.ink)
                .opacity(isActive ? 1 : 0.5)
                .shadow(color: MananaTheme.paper.opacity(0.6), radius: 2, y: 1)
                .contentShape(Rectangle())
        }
    }

    private func paletteCrayonImageName(for color: Color) -> String {
        switch color {
        case .red: return "IconCrayonRed"
        case .yellow: return "IconCrayonYellow"
        case .green: return "IconCrayonGreen"
        case .blue: return "IconCrayonBlue"
        case .white: return "IconCrayonWhite"
        default: return "IconCrayonBlack"
        }
    }

    @ViewBuilder
    private var backgroundArt: some View {
        if let uiImage = Self.backgroundUIImage(for: background) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: entry.weatherCondition.gradientColors(isDay: true),
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private static func backgroundUIImage(for background: WeatherBackground) -> UIImage? {
        if let cached = backgroundCache[background] { return cached }
        guard let url = Bundle.main.url(forResource: background.imageName, withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path)
        else { return nil }
        backgroundCache[background] = image
        return image
    }

    private func loadDrawing() {
        canvasView.drawing = DrawingStorage.shared.load(fileName: entry.drawingFileName)
        canvasView.undoManager?.removeAllActions()
        canUndo = false
        canRedo = false
        selectedColor = .black
    }

    /// Selects the eraser, and on the third consecutive tap wipes the drawing —
    /// mirrors the main screen's behavior.
    private func handleEraserTap() {
        let now = Date()
        if now.timeIntervalSince(lastEraserTapAt) > 1.5 {
            eraserTapCount = 0
        }
        lastEraserTapAt = now
        eraserTapCount += 1
        isErasing = true

        if eraserTapCount >= 3 {
            eraserTapCount = 0
            canvasView.drawing = PKDrawing()
            canvasView.undoManager?.removeAllActions()
            canUndo = false
            canRedo = false
            persist(PKDrawing())
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func persist(_ drawing: PKDrawing) {
        DrawingStorage.shared.save(drawing, fileName: entry.drawingFileName)

        // Only today's entry drives the widget's shared drawing.
        if isToday {
            if drawing.bounds.isEmpty {
                SharedDrawingStore.clear()
            } else {
                var image: UIImage!
                UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
                    image = drawing.image(from: drawing.bounds, scale: 2)
                }
                SharedDrawingStore.save(image, dateKey: SharedWeatherStore.dayKey(Date()))
            }
            WidgetCenter.shared.reloadAllTimelines()
        }

        onSaved()
    }
}
