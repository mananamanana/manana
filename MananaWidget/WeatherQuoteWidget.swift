import SwiftUI
import WidgetKit

/// Widget 1 — small square: today's weather and quote, no drawing.
struct WeatherQuoteWidgetView: View {
    var entry: WeatherEntry

    var body: some View {
        VStack(spacing: 4) {
            if let snapshot = entry.snapshot {
                HStack(spacing: 6) {
                    Text(snapshot.emoji)
                        .font(.system(size: 36))
                    if let temperature = snapshot.temperature {
                        Text("\(Int(temperature.rounded()))°")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                    }
                }
                Text(snapshot.conditionName)
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)

                if let detail = WidgetBackground.detailLine(for: snapshot) {
                    Text(detail)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                Text(snapshot.quoteText)
                    .font(.system(.subheadline, design: .serif).weight(.semibold).italic())
                    .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
            } else {
                Text("Mañana 앱을 열어\n오늘의 날씨를 가져와보세요")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            LinearGradient(colors: WidgetBackground.colors(for: entry.snapshot), startPoint: .top, endPoint: .bottom)
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
