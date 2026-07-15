import SwiftUI
import WidgetKit

@main
struct MananaWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeatherQuoteWidget()
        DrawingWidget()
        CombinedWidget()
        QuoteLockScreenWidget()
        QuoteLockScreenWideWidget()
    }
}
