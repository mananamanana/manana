import SwiftData
import SwiftUI

struct ArchiveListView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]
    @State private var viewMode: ViewMode = .calendar

    private enum ViewMode: String, CaseIterable, Identifiable {
        case calendar = "달력"
        case list = "목록"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "아직 기록된 하루가 없어요",
                        systemImage: "book",
                        description: Text("오늘 화면에 그림을 그리면 여기에 쌓여요.")
                    )
                    .tint(MananaTheme.clay)
                    .background(archiveBackground)
                } else {
                    switch viewMode {
                    case .calendar:
                        DiaryCalendarView(entries: entries)
                    case .list:
                        listContent
                    }
                }
            }
            .navigationTitle("다이어리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                if !entries.isEmpty {
                    ToolbarItem(placement: .principal) {
                        Picker("보기 방식", selection: $viewMode) {
                            ForEach(ViewMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                }
            }
        }
    }

    private var listContent: some View {
        List(entries) { entry in
            NavigationLink {
                DiaryEntryDetailView(entry: entry)
            } label: {
                row(for: entry)
            }
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(.primary.opacity(0.12))
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(archiveBackground)
    }

    private var archiveBackground: some View {
        Image("CalendarBackground")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }

    /// Styled like an anthology's table of contents — a folio number
    /// (this quote's place among the year's 365), date, italic preview,
    /// and a small, secondary weather mark.
    private func row(for entry: DiaryEntry) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(folio(for: entry.date))
                .font(.manana(size: 15, weight: .semibold))
                .monospacedDigit()
                .tracking(0.5)
                .foregroundStyle(.primary.opacity(0.7))
                .frame(width: 32, alignment: .leading)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date, format: .dateTime.year().month().day())
                    .font(.manana(size: 19, weight: .semibold))
                    // `.primary` rather than the fixed ink-brown, which was
                    // nearly invisible against Dark Mode's system background
                    // showing through this view's faint paper tint.
                    .foregroundStyle(.primary)
                Text(entry.quoteText)
                    .font(.manana(size: 15).italic())
                    .foregroundStyle(.primary.opacity(0.85))
            }

            Spacer(minLength: 0)

            WeatherIcon(name: WeatherBackground(condition: entry.weatherCondition).iconName)
                .frame(width: 22, height: 22)
                .foregroundStyle(.primary.opacity(0.28))
                .padding(.top, 2)
        }
    }

    private func folio(for date: Date) -> String {
        String(format: "%03d", Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1)
    }
}
