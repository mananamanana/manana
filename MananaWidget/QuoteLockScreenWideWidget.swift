import SwiftUI
import WidgetKit

/// Same quote content as `QuoteLockScreenWidget`, but styled for when it's
/// the only widget on its Lock Screen row — Apple renders `.accessoryRectangular`
/// wider when nothing shares the row with it, so this leans into that with a
/// larger, bolder type treatment rather than the compact one sized to sit
/// alongside another widget.
struct QuoteLockScreenWideWidgetView: View {
    var entry: WeatherEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.quoteText)
                        // No line cap and a low minimum scale, prioritizing
                        // "never truncates with …" over matching the
                        // title's size below — a long quote renders smaller
                        // than the title rather than losing any text.
                        .font(.system(size: 16, weight: .bold))
                        .minimumScaleFactor(0.4)
                        .multilineTextAlignment(.leading)
                    if let bookTitle = snapshot.quoteBookTitle {
                        Text("『\(bookTitle)』")
                            .font(.system(size: 16, weight: .regular))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .opacity(0.75)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            } else {
                Text("Mañana에서 오늘의 문장을 가져와보세요")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(3)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct QuoteLockScreenWideWidget: Widget {
    let kind = "QuoteLockScreenWideWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MananaWidgetProvider()) { entry in
            QuoteLockScreenWideWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘의 문장 (넓게)")
        .description("잠금화면 한 줄을 혼자 차지할 때 더 크고 진하게 보여줘요.")
        .supportedFamilies([.accessoryRectangular])
    }
}
