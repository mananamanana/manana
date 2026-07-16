import SwiftUI
import WidgetKit

/// Widget 1 — small square: today's weather and quote, no drawing.
struct WeatherQuoteWidgetView: View {
    var entry: WeatherEntry

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            if let snapshot = entry.snapshot {
                // Quote-only now — no weather info competes with it.
                Text(snapshot.quoteText)
                    .font(.manana(size: 20, relativeTo: .subheadline, weight: .semibold).italic())
                    .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot))
                    .multilineTextAlignment(.center)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
        .configurationDisplayName("오늘의 문장")
        .description("오늘의 문장을 보여줘요.")
        .supportedFamilies([.systemSmall])
    }
}
