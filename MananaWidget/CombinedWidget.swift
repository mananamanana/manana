import SwiftUI
import WidgetKit

/// Widget 3 — medium (wide): weather, quote, and today's drawing together.
struct CombinedWidgetView: View {
    var entry: WeatherEntry

    private var drawingImage: UIImage? {
        SharedDrawingStore.loadImage(forDayKey: SharedWeatherStore.dayKey(entry.date))
    }

    var body: some View {
        let drawing = drawingImage
        // Only reserve the left drawing slot when there's actually a drawing;
        // otherwise the weather + quote fill the full widget width with no
        // empty left margin.
        HStack(spacing: drawing == nil ? 0 : 12) {
            if let drawing {
                Image(uiImage: drawing)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            VStack(alignment: .leading, spacing: 6) {
                if let snapshot = entry.snapshot {
                    // Solid ink color + noticeably bigger type instead of
                    // `.secondary` gray at caption-size — against busy
                    // background art, the dimmed small text was reading as
                    // basically invisible.
                    HStack(spacing: 6) {
                        if let icon = WidgetBackground.icon(for: entry.snapshot) {
                            icon
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                                .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot))
                        } else {
                            Image(systemName: snapshot.symbolName)
                                .font(.system(size: 26))
                                .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot))
                        }
                        if let temperature = snapshot.temperature {
                            Text("\(Int(temperature.rounded()))°")
                                .font(.manana(.title2))
                                .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot))
                        }
                        Text(snapshot.conditionName)
                            .font(.manana(.subheadline))
                            .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot).opacity(0.75))
                    }

                    if let detail = WidgetBackground.detailLine(for: snapshot) {
                        Text(detail)
                            .font(.manana(.footnote))
                            .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot).opacity(0.65))
                    }

                    Text(snapshot.quoteText)
                        .font(.manana(size: 20, relativeTo: .caption, weight: .semibold).italic())
                        .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot))
                        // No hard line cap: shrink to fit so the quote isn't cut.
                        .lineLimit(nil)
                        .minimumScaleFactor(0.4)
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
}

struct CombinedWidget: Widget {
    // Kind renamed (v2) to force a fresh WidgetKit registration — see the note
    // in WeatherQuoteWidget; the old kind stayed blank on iPad.
    let kind = "MananaCombinedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MananaWidgetProvider()) { entry in
            CombinedWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘의 기록")
        .description("날씨, 문장, 그림을 한 번에 보여줘요.")
        .supportedFamilies([.systemMedium])
    }
}
