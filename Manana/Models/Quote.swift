import Foundation

/// A single book quote. `weatherTags` controls which weather conditions this
/// quote is allowed to appear under; use "any" for a quote that fits every condition.
struct Quote: Codable, Identifiable, Hashable {
    var id: String
    var text: String
    var bookTitle: String?
    var author: String?
    var weatherTags: [String]

    static let anyTag = "any"

    func matches(_ condition: WeatherCondition) -> Bool {
        weatherTags.contains(Self.anyTag) || weatherTags.contains(condition.rawValue)
    }
}
