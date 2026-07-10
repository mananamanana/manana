import Foundation
import SwiftData

/// One archived day: a snapshot of the weather and quote that were shown,
/// plus a pointer to that day's freehand drawing file. The quote text is
/// copied in at creation time so past entries stay stable even if the
/// quote pool changes later.
@Model
final class DiaryEntry {
    @Attribute(.unique) var dayKey: String
    var date: Date
    var weatherConditionRaw: String
    var temperature: Double?
    var quoteText: String
    var quoteBookTitle: String?
    var quoteAuthor: String?
    var drawingFileName: String

    init(
        date: Date,
        weatherCondition: WeatherCondition,
        temperature: Double?,
        quoteText: String,
        quoteBookTitle: String?,
        quoteAuthor: String?,
        drawingFileName: String
    ) {
        self.dayKey = DrawingStorage.dateKey(date)
        self.date = date
        self.weatherConditionRaw = weatherCondition.rawValue
        self.temperature = temperature
        self.quoteText = quoteText
        self.quoteBookTitle = quoteBookTitle
        self.quoteAuthor = quoteAuthor
        self.drawingFileName = drawingFileName
    }

    var weatherCondition: WeatherCondition {
        WeatherCondition(rawValue: weatherConditionRaw) ?? .cloudy
    }
}
