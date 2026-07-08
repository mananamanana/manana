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
                } else {
                    List(entries) { entry in
                        NavigationLink {
                            DiaryEntryDetailView(entry: entry)
                        } label: {
                            row(for: entry)
                        }
                    }
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

    private func row(for entry: DiaryEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.weatherCondition.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date, format: .dateTime.year().month().day())
                    .font(.subheadline.weight(.medium))
                Text(entry.quoteText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
