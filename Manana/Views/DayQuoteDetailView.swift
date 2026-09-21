import SwiftUI

/// A read-only quote page for a calendar day that has *no* recorded diary
/// entry. Days the user actually drew on open `DiaryEntryDetailView` (with
/// their drawing + weather); every other past day still has a curated
/// sheet quote, so tapping it here shows just that quote on the paper
/// background rather than being unselectable. No drawing, weather, or edit
/// controls — there's no entry to attach them to.
struct DayQuoteDetailView: View {
    let date: Date

    private var quote: (text: String, bookTitle: String?, author: String?)? {
        QuoteService.sheetQuote(for: date)
    }

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yy.M.d(EEE)"
        return formatter.string(from: date)
    }

    private var byline: String? {
        guard let quote else { return nil }
        let parts = [quote.bookTitle.map { "『\($0)』" }, quote.author].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    var body: some View {
        ZStack {
            Image("CalendarBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 0)
                quoteBlock
                Spacer(minLength: 0)
            }
        }
        .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var quoteBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dateLine)
                .font(.manana(size: 20, weight: .semibold))
                .foregroundStyle(MananaTheme.ink.opacity(0.55))

            Text(quote?.text ?? "이 날의 문장이 아직 없어요.")
                .font(.manana(size: 29, weight: .semibold))
                .multilineTextAlignment(.leading)
                .foregroundStyle(MananaTheme.ink)
                .lineSpacing(6)

            if let byline {
                Text(byline)
                    .font(.manana(size: 19))
                    .foregroundStyle(MananaTheme.ink.opacity(0.75))
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
