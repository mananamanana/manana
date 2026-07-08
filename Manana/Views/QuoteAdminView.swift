import SwiftUI

/// Temporary data-entry screen for filling in the 365-quote pool by hand
/// while the real dataset isn't ready yet. Wrapped in #if DEBUG so it's
/// compiled out of release builds entirely — no risk of it shipping.
#if DEBUG
struct QuoteAdminView: View {
    @EnvironmentObject private var quoteService: QuoteService
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var source = ""
    @State private var selectedTags: Set<String> = []

    private let allTags = WeatherCondition.allCases.map(\.rawValue) + [Quote.anyTag]

    var body: some View {
        NavigationStack {
            Form {
                Section("새 문장") {
                    TextField("문장", text: $text, axis: .vertical)
                    TextField("출처 (선택)", text: $source)
                }
                Section("어울리는 날씨") {
                    ForEach(allTags, id: \.self) { tag in
                        Toggle(tagLabel(tag), isOn: bindingForTag(tag))
                    }
                }
                Section("등록된 문장 (\(quoteService.quotes.count))") {
                    ForEach(quoteService.quotes) { quote in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(quote.text).font(.footnote)
                            Text(quote.weatherTags.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("문장 관리 (Dev)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") { addQuote() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func tagLabel(_ tag: String) -> String {
        if tag == Quote.anyTag { return "모든 날씨" }
        return WeatherCondition(rawValue: tag)?.displayName ?? tag
    }

    private func bindingForTag(_ tag: String) -> Binding<Bool> {
        Binding(
            get: { selectedTags.contains(tag) },
            set: { isOn in
                if isOn { selectedTags.insert(tag) } else { selectedTags.remove(tag) }
            }
        )
    }

    private func addQuote() {
        quoteService.addCustomQuote(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : source,
            weatherTags: Array(selectedTags)
        )
        text = ""
        source = ""
        selectedTags = []
    }
}
#endif
