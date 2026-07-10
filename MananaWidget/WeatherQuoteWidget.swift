import SwiftUI
import WidgetKit

/// Widget 1 — small square: today's weather and quote, no drawing.
struct WeatherQuoteWidgetView: View {
    var entry: WeatherEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let snapshot = entry.snapshot {
                // The quote is the point of this widget — the weather line
                // is just a small header, not a competing focal point.
                HStack(spacing: 4) {
                    Image(systemName: snapshot.symbolName)
                        .font(.system(size: 13))
                    if let temperature = snapshot.temperature {
                        Text("\(Int(temperature.rounded()))°")
                            .font(.manana(size: 13, weight: .semibold))
                    }
                    Text(snapshot.conditionName)
                        .font(.manana(.caption2))
                        .foregroundStyle(.secondary)
                    if let detail = WidgetBackground.detailLine(for: snapshot) {
                        Text("· \(detail)")
                            .font(.manana(.caption2))
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)

                Spacer(minLength: 6)

                Text(snapshot.quoteText)
                    .font(.manana(.subheadline, weight: .semibold).italic())
                    .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot))
                    .multilineTextAlignment(.leading)
                    .lineLimit(6)
                    .minimumScaleFactor(0.6)
            } else {
                Text("Mañana 앱을 열어\n오늘의 날씨를 가져와보세요")
                    .font(.manana(.caption2))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            WidgetBackground.art(for: entry.snapshot)
        }
    }
}

struct WeatherQuoteWidget: Widget {
    let kind = "WeatherQuoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MananaWidgetProvider()) { entry in
            WeatherQuoteWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘의 날씨")
        .description("오늘의 날씨와 문장을 보여줘요.")
        .supportedFamilies([.systemSmall])
    }
}
