import SwiftUI
import WidgetKit

/// Widget 2 — small square: just today's drawing, no text at all.
struct DrawingWidgetView: View {
    var entry: WeatherEntry

    private var drawingImage: UIImage? {
        SharedDrawingStore.loadImage()
    }

    var body: some View {
        Group {
            if let uiImage = drawingImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Text("아직 그린 그림이 없어요")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            LinearGradient(colors: WidgetBackground.colors(for: entry.snapshot), startPoint: .top, endPoint: .bottom)
        }
    }
}

struct DrawingWidget: Widget {
    let kind = "DrawingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MananaWidgetProvider()) { entry in
            DrawingWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘의 그림")
        .description("오늘 그린 그림만 보여줘요.")
        .supportedFamilies([.systemSmall])
    }
}
