import SwiftUI
import WidgetKit

/// Lock Screen widget — just today's quote, no weather, no drawing. The
/// system renders Lock Screen widgets in a monochrome/tinted style it
/// controls (respecting whatever tint the user picked), so this deliberately
/// skips any custom color or background art — those would just be ignored
/// or fought with by the system rendering anyway.
struct QuoteLockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WeatherEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .accessoryInline:
                    Text(snapshot.quoteText)
                default:
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.quoteText)
                            // Semibold reads noticeably clearer than medium
                            // once the system applies its monochrome/tinted
                            // lock screen rendering, which otherwise washes
                            // out thinner strokes. No line cap and a low
                            // minimum scale, prioritizing "never truncates
                            // with …" over matching the title's size below —
                            // a long quote will render smaller than the
                            // title rather than lose any text.
                            .font(.system(.footnote, weight: .semibold))
                            .lineSpacing(-1)
                            .minimumScaleFactor(0.4)
                            .multilineTextAlignment(.leading)
                        if let bookTitle = snapshot.quoteBookTitle {
                            Text("『\(bookTitle)』")
                                .font(.system(.footnote))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .opacity(0.7)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
            } else {
                Text("Mañana에서 오늘의 문장을 가져와보세요")
                    .font(.system(.footnote))
                    .lineLimit(family == .accessoryInline ? 1 : 3)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct QuoteLockScreenWidget: Widget {
    let kind = "QuoteLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MananaWidgetProvider()) { entry in
            QuoteLockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘의 문장")
        .description("잠금화면에 오늘의 문장만 보여줘요.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}
