import SwiftUI

/// A month grid for the diary archive — each day with a recorded entry
/// shows that day's weather icon and links to its detail view; days
/// without one are shown dimmed and unselectable.
struct DiaryCalendarView: View {
    let entries: [DiaryEntry]

    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: Date())

    private let calendar = Calendar.current
    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

    private var entriesByDayKey: [String: DiaryEntry] {
        Dictionary(uniqueKeysWithValues: entries.map { (DrawingStorage.dateKey($0.date), $0) })
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: displayedMonth)
    }

    /// Leading `nil`s pad the first week to align on the correct weekday;
    /// trailing `nil`s round the grid out to a whole number of weeks.
    private var daysInGrid: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<daysInMonth {
            days.append(calendar.date(byAdding: .day, value: offset, to: monthInterval.start))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button { shiftMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthTitle)
                    .font(.manana(.headline, weight: .semibold))
                Spacer()
                Button { shiftMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .foregroundStyle(MananaTheme.ink)
            .padding(.horizontal, 24)
            .padding(.top, 12)

            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.manana(.caption2))
                        .foregroundStyle(MananaTheme.ink.opacity(0.45))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 14)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(daysInGrid.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(for: date)
                    } else {
                        Color.clear.frame(height: 54)
                    }
                }
            }
            .padding(.horizontal, 14)

            Spacer(minLength: 0)
        }
        .background(MananaTheme.paper.opacity(0.2))
    }

    private func shiftMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let entry = entriesByDayKey[DrawingStorage.dateKey(date)]

        if let entry {
            NavigationLink {
                DiaryEntryDetailView(entry: entry)
            } label: {
                dayContent(date: date, entry: entry)
            }
            .buttonStyle(.plain)
        } else {
            dayContent(date: date, entry: nil)
        }
    }

    private func dayContent(date: Date, entry: DiaryEntry?) -> some View {
        VStack(spacing: 5) {
            Text("\(calendar.component(.day, from: date))")
                .font(.manana(.footnote, weight: entry != nil ? .semibold : .regular))
                .foregroundStyle(entry != nil ? MananaTheme.ink : MananaTheme.ink.opacity(0.3))

            WeatherIcon(name: WeatherBackground(condition: entry?.weatherCondition ?? .clear).iconName)
                .frame(width: 18, height: 18)
                .foregroundStyle(entry != nil ? MananaTheme.clay : .clear)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(
            Circle()
                .strokeBorder(MananaTheme.clay.opacity(calendar.isDateInToday(date) ? 0.5 : 0), lineWidth: 1.5)
                .padding(6)
        )
    }
}
