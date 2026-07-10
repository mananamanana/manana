import Foundation

/// Loads the bundled seed quotes and resolves "today's quote" from a
/// day-of-year rotation that falls back to a weather-tag match when the
/// rotation pick doesn't fit today.
@MainActor
final class QuoteService: ObservableObject {
    @Published private(set) var quotes: [Quote] = []

    init() {
        reload()
    }

    func reload() {
        quotes = loadBundledQuotes()
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
}
