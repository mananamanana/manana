import SwiftUI
import WidgetKit

/// Widget 6 — large & extra-large: the app's home scene at a glance. `large`
/// stacks weather → drawing → quote vertically; `extraLarge` (iPad only) puts
/// the drawing on the left and the weather + quote on the right, using the wide
/// canvas iPad gives.
struct LargeCombinedWidgetView: View {
    var entry: WeatherEntry
    @Environment(\.widgetFamily) private var family

    private var drawingImage: UIImage? {
        SharedDrawingStore.loadImage(forDayKey: SharedWeatherStore.dayKey(entry.date))
    }

    private var byline: String? {
        guard let snapshot = entry.snapshot else { return nil }
        let parts = [snapshot.quoteBookTitle.map { "『\($0)』" }, snapshot.quoteAuthor].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    var body: some View {
        Group {
            if family == .systemExtraLarge {
                extraLargeLayout
            } else {
                largeLayout
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            WidgetBackground.art(for: entry.snapshot)
        }
    }

    // MARK: - large (vertical)

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            weatherRow

            if let drawing = drawingImage {
                HStack {
                    Spacer(minLength: 0)
                    Image(uiImage: drawing)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 150)
                    Spacer(minLength: 0)
                }
            }

            Spacer(minLength: 0)

            quoteBlock(quoteSize: 24, quoteLines: drawingImage == nil ? 8 : 4)
        }
    }

    // MARK: - extra large (iPad: side by side)

    private var extraLargeLayout: some View {
        HStack(alignment: .top, spacing: 24) {
            if let drawing = drawingImage {
                Image(uiImage: drawing)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }

            VStack(alignment: .leading, spacing: 18) {
                weatherRow
                Spacer(minLength: 0)
                quoteBlock(quoteSize: 30, quoteLines: drawingImage == nil ? 10 : 7)
            }
            .frame(maxWidth: drawingImage == nil ? .infinity : nil)
        }
    }

    // MARK: - pieces

    @ViewBuilder
    private var weatherRow: some View {
        if let snapshot = entry.snapshot {
            HStack(spacing: 8) {
                if let icon = WidgetBackground.icon(for: entry.snapshot) {
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot))
                } else {
                    Image(systemName: snapshot.symbolName)
                        .font(.system(size: 34))
                        .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot))
                }
                if let temperature = snapshot.temperature {
                    Text("\(Int(temperature.rounded()))°")
                        .font(.manana(.title))
                        .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot))
                }
                Text(snapshot.conditionName)
                    .font(.manana(.title3))
                    .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot).opacity(0.75))
                if let detail = WidgetBackground.detailLine(for: snapshot) {
                    Text(detail)
                        .font(.manana(.subheadline))
                        .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot).opacity(0.6))
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func quoteBlock(quoteSize: CGFloat, quoteLines: Int) -> some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.quoteText)
                    .font(.manana(size: quoteSize, relativeTo: .body, weight: .semibold))
                    .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot))
                    .lineLimit(quoteLines)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)

                if let byline {
                    Text(byline)
                        .font(.manana(.subheadline))
                        .foregroundStyle(WidgetBackground.quoteColor(for: entry.snapshot).opacity(0.7))
                }
            }
        } else {
            Text("Mañana 앱을 열어\n오늘의 날씨를 가져와보세요")
                .font(.manana(.body))
                .foregroundStyle(.secondary)
        }
    }
}

struct LargeCombinedWidget: Widget {
    let kind = "LargeCombinedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MananaWidgetProvider()) { entry in
            LargeCombinedWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘의 기록 (크게)")
        .description("날씨·문장·그림을 큰 화면으로 보여줘요. 아이패드에서는 초대형까지 지원해요.")
        .supportedFamilies([.systemLarge, .systemExtraLarge])
    }
}
