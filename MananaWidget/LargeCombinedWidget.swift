import SwiftUI
import WidgetKit

/// The main Mañana widget — one widget that adapts to every size, so all
/// families render through the same code path that works reliably (the older
/// per-size widgets rendered blank on iPad). Small: weather + quote. Medium:
/// drawing beside weather + quote. Large: stacked vertically. Extra-large
/// (iPad): drawing on the left, weather + quote on the right.
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

    private var ink: Color { WidgetBackground.quoteColor(for: entry.snapshot) }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: smallLayout
            case .systemMedium: mediumLayout
            case .systemExtraLarge: extraLargeLayout
            default: largeLayout
            }
        }
        .padding(family == .systemSmall ? 14 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            WidgetBackground.art(for: entry.snapshot)
        }
    }

    // MARK: - small (quote only, compact weather)

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            compactWeatherRow
            Spacer(minLength: 0)
            if let snapshot = entry.snapshot {
                Text(snapshot.quoteText)
                    .font(.manana(size: 15, relativeTo: .caption, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(5)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                placeholderText
            }
        }
    }

    // MARK: - medium (drawing + weather/quote)

    private var mediumLayout: some View {
        HStack(spacing: drawingImage == nil ? 0 : 12) {
            if let drawing = drawingImage {
                Image(uiImage: drawing)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            VStack(alignment: .leading, spacing: 6) {
                weatherRow(iconSize: 26, tempFont: .title2, condFont: .subheadline)
                if let snapshot = entry.snapshot {
                    Text(snapshot.quoteText)
                        .font(.manana(size: 19, relativeTo: .caption, weight: .semibold))
                        .foregroundStyle(ink)
                        .lineLimit(3)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    placeholderText
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - large (vertical)

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            weatherRow(iconSize: 34, tempFont: .title, condFont: .title3)
            if let drawing = drawingImage {
                HStack {
                    Spacer(minLength: 0)
                    Image(uiImage: drawing).resizable().scaledToFit().frame(maxHeight: 150)
                    Spacer(minLength: 0)
                }
            }
            Spacer(minLength: 0)
            quoteBlock(quoteSize: 24, quoteLines: drawingImage == nil ? 8 : 4)
        }
    }

    // MARK: - extra large (iPad)

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
                weatherRow(iconSize: 34, tempFont: .title, condFont: .title3)
                Spacer(minLength: 0)
                quoteBlock(quoteSize: 30, quoteLines: drawingImage == nil ? 10 : 7)
            }
            .frame(maxWidth: drawingImage == nil ? .infinity : nil)
        }
    }

    // MARK: - pieces

    private var placeholderText: some View {
        Text("Mañana 앱을 열어\n오늘의 날씨를 가져와보세요")
            .font(.manana(.caption2))
            .foregroundStyle(ink.opacity(0.7))
    }

    @ViewBuilder
    private var compactWeatherRow: some View {
        if let snapshot = entry.snapshot {
            HStack(spacing: 6) {
                weatherIcon(size: 24)
                if let temperature = snapshot.temperature {
                    Text("\(Int(temperature.rounded()))°")
                        .font(.manana(.title3))
                        .foregroundStyle(ink)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func weatherRow(iconSize: CGFloat, tempFont: Font.TextStyle, condFont: Font.TextStyle) -> some View {
        if let snapshot = entry.snapshot {
            HStack(spacing: 8) {
                weatherIcon(size: iconSize)
                if let temperature = snapshot.temperature {
                    Text("\(Int(temperature.rounded()))°")
                        .font(.manana(tempFont))
                        .foregroundStyle(ink)
                }
                Text(snapshot.conditionName)
                    .font(.manana(condFont))
                    .foregroundStyle(ink.opacity(0.75))
                if let detail = WidgetBackground.detailLine(for: snapshot) {
                    Text(detail)
                        .font(.manana(.footnote))
                        .foregroundStyle(ink.opacity(0.6))
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func weatherIcon(size: CGFloat) -> some View {
        if let icon = WidgetBackground.icon(for: entry.snapshot) {
            icon.resizable().scaledToFit().frame(width: size, height: size).foregroundStyle(ink)
        } else if let snapshot = entry.snapshot {
            Image(systemName: snapshot.symbolName).font(.system(size: size)).foregroundStyle(ink)
        }
    }

    @ViewBuilder
    private func quoteBlock(quoteSize: CGFloat, quoteLines: Int) -> some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.quoteText)
                    .font(.manana(size: quoteSize, relativeTo: .body, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(quoteLines)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                if let byline {
                    Text(byline)
                        .font(.manana(.subheadline))
                        .foregroundStyle(ink.opacity(0.7))
                }
            }
        } else {
            placeholderText
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
