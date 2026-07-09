import SwiftData
import SwiftUI

struct ArchiveListView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]

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
                    .background(MananaTheme.paper.opacity(0.2))
                } else {
                    List(entries) { entry in
                        NavigationLink {
                            DiaryEntryDetailView(entry: entry)
                        } label: {
                            row(for: entry)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(MananaTheme.ink.opacity(0.12))
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(MananaTheme.paper.opacity(0.2))
                }
            }
            .navigationTitle("다이어리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    /// Styled like an anthology's table of contents — a folio number
    /// (this quote's place among the year's 365), date, italic preview,
    /// and a small, secondary weather mark.
    private func row(for entry: DiaryEntry) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(folio(for: entry.date))
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .tracking(0.5)
                .foregroundStyle(MananaTheme.clay)
                .frame(width: 32, alignment: .leading)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date, format: .dateTime.year().month().day())
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(MananaTheme.ink)
                Text(entry.quoteText)
                    .font(.mananaQuote(.footnote))
                    .foregroundStyle(entry.weatherCondition.quoteInkColor(isDay: true).opacity(0.85))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: entry.weatherCondition.symbolName)
                .font(.caption)
                .foregroundStyle(MananaTheme.ink.opacity(0.28))
                .padding(.top, 2)
        }
    }

    private func folio(for date: Date) -> String {
        String(format: "%03d", Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1)
    }
}
