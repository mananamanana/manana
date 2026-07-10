import SwiftUI
import WidgetKit

/// Widget 3 — medium (wide): weather, quote, and today's drawing together.
struct CombinedWidgetView: View {
    var entry: WeatherEntry

    private var drawingImage: UIImage? {
        SharedDrawingStore.loadImage()
    }

    var body: some View {
        HStack(spacing: 12) {
            drawingThumbnail
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                if let snapshot = entry.snapshot {
                    HStack(spacing: 4) {
                        Image(systemName: snapshot.symbolName)
                            .font(.system(size: 15))
                        if let temperature = snapshot.temperature {
                            Text("\(Int(temperature.rounded()))°")
                                .font(.manana(.headline))
                        }
                        Text(snapshot.conditionName)
                            .font(.manana(.caption2))
                            .foregroundStyle(.secondary)
                    }

                    if let detail = WidgetBackground.detailLine(for: snapshot) {
                        Text(detail)
                            .font(.manana(.caption2))
                            .foregroundStyle(.secondary)
                    }

                    Text(snapshot.quoteText)
                        .font(.mananaQuote(.caption))
                        .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Mañana 앱을 열어\n오늘의 날씨를 가져와보세요")
                        .font(.manana(.caption2))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            WidgetBackground.art(for: entry.snapshot)
        }
    }

    @ViewBuilder
    private var drawingThumbnail: some View {
        if let uiImage = drawingImage {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.25))
        }
    }
}

struct CombinedWidget: Widget {
    let kind = "CombinedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MananaWidgetProvider()) { entry in
            CombinedWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘의 기록")
        .description("날씨, 문장, 그림을 한 번에 보여줘요.")
        .supportedFamilies([.systemMedium])
    }
}
