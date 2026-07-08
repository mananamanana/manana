import Foundation

/// Loads the bundled seed quotes plus any quotes added through the dev-only
/// admin tool, and resolves "today's quote" from a day-of-year rotation that
/// falls back to a weather-tag match when the rotation pick doesn't fit today.
@MainActor
final class QuoteService: ObservableObject {
    @Published private(set) var quotes: [Quote] = []

    private let customQuotesURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("custom_quotes.json")
    }()

    init() {
        reload()
    }

    func reload() {
        quotes = loadBundledQuotes() + loadCustomQuotes()
    }

    /// Adds a quote from the dev-only admin tool and persists it to Documents
    /// so it survives relaunches without needing to touch the app bundle.
    func addCustomQuote(text: String, source: String?, weatherTags: [String]) {
        var custom = loadCustomQuotes()
        let quote = Quote(
            id: "custom-\(UUID().uuidString.prefix(8))",
            text: text,
            source: source,
            weatherTags: weatherTags.isEmpty ? [Quote.anyTag] : weatherTags
        )
        custom.append(quote)
        saveCustomQuotes(custom)
        reload()
    }

    func quoteForToday(condition: WeatherCondition, date: Date = Date()) -> Quote? {
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

    private func loadCustomQuotes() -> [Quote] {
        guard let data = try? Data(contentsOf: customQuotesURL),
              let decoded = try? JSONDecoder().decode([Quote].self, from: data)
        else {
            return []
        }
        return decoded
    }

    private func saveCustomQuotes(_ quotes: [Quote]) {
        guard let data = try? JSONEncoder().encode(quotes) else { return }
        try? data.write(to: customQuotesURL, options: .atomic)
    }
}
