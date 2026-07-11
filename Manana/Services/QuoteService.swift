import Foundation

/// Loads today's quote from the "날짜별 문장" Google Sheet (published as CSV,
/// no API key needed), keyed by calendar day (month/day, recurring every
/// year). Most days in the sheet are intentionally left blank — those fall
/// back to the bundled seed quotes' day-of-year rotation, weather-tag
/// matched, same as before the sheet existed.
@MainActor
final class QuoteService: ObservableObject {
    @Published private(set) var quotes: [Quote] = []
    @Published private(set) var dailyQuotes: [String: DailyQuote] = [:]
    @Published private(set) var lastSyncError: String?

    /// File > Share > Publish to web (or "Anyone with the link" viewer
    /// access) is required — this endpoint 302s to a Google login page
    /// otherwise. `gid=0` is the sheet's first (and only) tab.
    private static let sheetCSVURL = URL(
        string: "https://docs.google.com/spreadsheets/d/1VuECW7b3H5FlQ3FUtDe796h-3OLOMdATTbcBVJWO-TA/export?format=csv&gid=0"
    )!

    private static let cacheKey = "quoteService.dailyQuotes.cache"

    init() {
        reload()
        dailyQuotes = Self.loadCachedDailyQuotes()
    }

    func reload() {
        quotes = loadBundledQuotes()
    }

    /// Re-fetches the sheet in the background; safe to call repeatedly
    /// (e.g. on every app foreground) since it just replaces `dailyQuotes`
    /// once the request succeeds.
    func refresh() {
        Task { await fetchRemoteQuotes() }
    }

    func quoteForToday(condition: WeatherCondition, date: Date = Date()) -> Quote? {
        if let daily = dailyQuote(for: date) {
            return daily
        }
        return seedQuoteForToday(condition: condition, date: date)
    }

    /// KST-anchored, matching every other "what day is it" calculation in
    /// this app (see `DrawingStorage.dateKey`).
    private func dailyQuote(for date: Date) -> Quote? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        guard let row = dailyQuotes[DailyQuote.key(month: month, day: day)],
              !row.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        return Quote(
            id: "sheet-\(row.key)",
            text: row.text,
            bookTitle: row.bookTitle,
            author: row.author,
            weatherTags: [Quote.anyTag]
        )
    }

    private func seedQuoteForToday(condition: WeatherCondition, date: Date) -> Quote? {
        guard !quotes.isEmpty else { return nil }

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let baseIndex = (dayOfYear - 1) % quotes.count
        let baseQuote = quotes[baseIndex]

        if baseQuote.matches(condition) {
            return baseQuote
        }

        let matching = quotes.filter { $0.matches(condition) }
        guard !matching.isEmpty else { return baseQuote }
        let matchingIndex = dayOfYear % matching.count
        return matching[matchingIndex]
    }

    private func loadBundledQuotes() -> [Quote] {
        guard let url = Bundle.main.url(forResource: "quotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Quote].self, from: data)
        else {
            return []
        }
        return decoded
    }

    private func fetchRemoteQuotes() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: Self.sheetCSVURL)
            guard let csv = String(data: data, encoding: .utf8) else {
                throw QuoteServiceError.decoding
            }
            let parsed = Self.parseDailyQuotes(csv: csv)
            guard !parsed.isEmpty else { throw QuoteServiceError.emptySheet }

            dailyQuotes = parsed
            lastSyncError = nil
            Self.cacheDailyQuotes(parsed)
        } catch {
            // Keep whatever was last cached (or the bundled fallback) —
            // a failed refresh shouldn't blank out today's quote.
            lastSyncError = "문장 시트를 불러오지 못했어요: \(error.localizedDescription)"
        }
    }

    private enum QuoteServiceError: LocalizedError {
        case decoding
        case emptySheet
        var errorDescription: String? {
            switch self {
            case .decoding: return "시트 데이터를 읽을 수 없어요."
            case .emptySheet: return "시트에서 문장을 찾지 못했어요."
            }
        }
    }

    // MARK: - CSV parsing

    /// Expected columns (header names are trimmed, order doesn't matter):
    /// 날짜 (M/d, e.g. "7/11"), 도서 한 줄 (quote text), 도서 명 (book title), 저자 (author).
    /// A hand-rolled parser is needed (not just `.split(",")`) because quote
    /// text itself contains embedded commas wrapped in quotes.
    private static func parseDailyQuotes(csv: String) -> [String: DailyQuote] {
        let rows = parseCSVRows(csv)
        guard let header = rows.first else { return [:] }

        let trimmedHeader = header.map { $0.trimmingCharacters(in: .whitespaces) }
        guard let dateIndex = trimmedHeader.firstIndex(of: "날짜") else { return [:] }
        let textIndex = trimmedHeader.firstIndex(of: "도서 한 줄")
        let titleIndex = trimmedHeader.firstIndex(of: "도서 명")
        let authorIndex = trimmedHeader.firstIndex(of: "저자")

        var result: [String: DailyQuote] = [:]
        for row in rows.dropFirst() {
            guard dateIndex < row.count else { continue }
            let dateParts = row[dateIndex].split(separator: "/")
            guard dateParts.count == 2,
                  let month = Int(dateParts[0].trimmingCharacters(in: .whitespaces)),
                  let day = Int(dateParts[1].trimmingCharacters(in: .whitespaces))
            else { continue }

            let text = textIndex.flatMap { $0 < row.count ? row[$0] : nil }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else { continue }

            let title = titleIndex.flatMap { $0 < row.count ? row[$0] : nil }?.trimmingCharacters(in: .whitespacesAndNewlines)
            let author = authorIndex.flatMap { $0 < row.count ? row[$0] : nil }?.trimmingCharacters(in: .whitespacesAndNewlines)

            let key = DailyQuote.key(month: month, day: day)
            result[key] = DailyQuote(
                month: month,
                day: day,
                text: text,
                bookTitle: (title?.isEmpty ?? true) ? nil : title,
                author: (author?.isEmpty ?? true) ? nil : author
            )
        }
        return result
    }

    /// Minimal RFC4180-style parser: handles quoted fields (with embedded
    /// commas/newlines) and `""` as an escaped quote. Google's CSV export
    /// uses `\r\n` line endings.
    private static func parseCSVRows(_ csv: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false

        // Iterates Unicode scalars rather than `Character` — Swift's
        // `Character` treats a CR+LF pair as a single grapheme cluster, so
        // comparing against "\r"/"\n" individually would silently never
        // match and leak the raw line break into field text.
        let scalars = Array(csv.unicodeScalars)
        let quote = Unicode.Scalar("\"")
        let comma = Unicode.Scalar(",")
        let cr = Unicode.Scalar("\r")
        let lf = Unicode.Scalar("\n")
        var i = 0
        while i < scalars.count {
            let scalar = scalars[i]
            if insideQuotes {
                if scalar == quote {
                    if i + 1 < scalars.count, scalars[i + 1] == quote {
                        field.append("\"")
                        i += 1
                    } else {
                        insideQuotes = false
                    }
                } else {
                    field.unicodeScalars.append(scalar)
                }
            } else if scalar == quote {
                insideQuotes = true
            } else if scalar == comma {
                row.append(field)
                field = ""
            } else if scalar == cr || scalar == lf {
                if scalar == cr, i + 1 < scalars.count, scalars[i + 1] == lf {
                    i += 1
                }
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.unicodeScalars.append(scalar)
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    // MARK: - Offline cache

    private static func cacheDailyQuotes(_ quotes: [String: DailyQuote]) {
        guard let data = try? JSONEncoder().encode(quotes) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private static func loadCachedDailyQuotes() -> [String: DailyQuote] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([String: DailyQuote].self, from: data)
        else { return [:] }
        return decoded
    }
}
