import SwiftUI

/// A month grid for the diary archive — each day with a recorded entry
/// shows that day's weather icon and links to its detail view; days
/// without one are shown dimmed and unselectable.
struct DiaryCalendarView: View {
    let entries: [DiaryEntry]
    var onEditInHome: ((Date) -> Void)? = nil

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
                .disabled(!canGoBack)
                .opacity(canGoBack ? 1 : 0.25)
                Spacer()
                Text(monthTitle)
                    .font(.manana(size: 22, weight: .semibold))
                Spacer()
                Button { shiftMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                }
            }
            // `.primary` rather than the fixed ink-brown — the calendar's
            // background tint is faint enough that the system's own dark
            // background shows through in Dark Mode, and the dark ink was
            // nearly invisible against it. `.primary` adapts automatically.
            .foregroundStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.top, 12)

            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.manana(size: 16))
                        .foregroundStyle(.primary.opacity(0.45))
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
        .contentShape(Rectangle())
        // Swipe left/right to change months (left = next, right = previous),
        // in addition to the chevrons. Respects the Jan 2026 lower bound.
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < -40 {
                        shiftMonth(by: 1)
                    } else if value.translation.width > 40 {
                        shiftMonth(by: -1)
                    }
                }
        )
        .background {
            Image("CalendarBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
    }

    /// The calendar never goes earlier than January 2026 — the app's first year.
    private var minimumMonthStart: Date? {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))
    }

    /// False when the displayed month is already the earliest allowed (Jan 2026),
    /// so the "previous month" control can be disabled.
    private var canGoBack: Bool {
        guard let minStart = minimumMonthStart,
              let currentStart = calendar.dateInterval(of: .month, for: displayedMonth)?.start
        else { return true }
        return currentStart > minStart
    }

    private func shiftMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        // Block going before Jan 2026.
        if value < 0,
           let minStart = minimumMonthStart,
           let newStart = calendar.dateInterval(of: .month, for: newMonth)?.start,
           newStart < minStart {
            return
        }
        withAnimation(.easeInOut(duration: 0.22)) {
            displayedMonth = newMonth
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let entry = entriesByDayKey[DrawingStorage.dateKey(date)]

        if let entry {
            NavigationLink {
                DiaryEntryDetailView(entry: entry, onEditInHome: onEditInHome)
            } label: {
                dayContent(date: date, entry: entry)
            }
            .buttonStyle(.plain)
        } else if isPastOrToday(date), QuoteService.sheetQuote(for: date) != nil {
            // Days the user never drew on still have a curated sheet quote —
            // let those be tapped to read that day's quote, instead of being
            // silently unselectable. Future days are left alone so tomorrow's
            // quote isn't spoiled.
            NavigationLink {
                DayQuoteDetailView(date: date)
            } label: {
                dayContent(date: date, entry: nil)
            }
            .buttonStyle(.plain)
        } else {
            dayContent(date: date, entry: nil)
        }
    }

    private func isPastOrToday(_ date: Date) -> Bool {
        calendar.compare(date, to: Date(), toGranularity: .day) != .orderedDescending
    }

    private func dayContent(date: Date, entry: DiaryEntry?) -> some View {
        VStack(spacing: 5) {
            Text("\(calendar.component(.day, from: date))")
                .font(.manana(size: 18, weight: entry != nil ? .semibold : .regular))
                .foregroundStyle(.primary)

            WeatherIcon(name: WeatherBackground(condition: entry?.weatherCondition ?? .clear).iconName)
                .frame(width: 18, height: 18)
                .foregroundStyle(entry != nil ? Color.primary : Color.clear)
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
