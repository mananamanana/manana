import Foundation

/// A single row from the "날짜별 문장" Google Sheet — one specific calendar
/// day (recurring every year, no year component) mapped to a quote.
struct DailyQuote: Codable, Hashable {
    var month: Int
    var day: Int
    var text: String
    var bookTitle: String?
    var author: String?

    /// Key used to look this row up by calendar day, e.g. "7/11".
    var key: String { Self.key(month: month, day: day) }

    static func key(month: Int, day: Int) -> String {
        "\(month)/\(day)"
    }
}
