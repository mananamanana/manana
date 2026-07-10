import SwiftUI

struct DiaryEntryDetailView: View {
    let entry: DiaryEntry

    @State private var shareImage: Image?

    private static let cardSize = CGSize(width: 360, height: 440)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                card
                    .frame(width: Self.cardSize.width, height: Self.cardSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                if let shareImage {
                    ShareLink(
                        item: shareImage,
                        preview: SharePreview("오늘의 기록", image: shareImage)
                    ) {
                        Label("공유하기", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(entry.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { renderShareImage() }
    }

    private var card: some View {
        ZStack {
            LinearGradient(
                colors: entry.weatherCondition.gradientColors(isDay: true),
                startPoint: .top,
                endPoint: .bottom
            )

            if let uiImage = DrawingStorage.shared.image(fileName: entry.drawingFileName, size: Self.cardSize) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            }

            VStack {
                Spacer()
                VStack(spacing: 8) {
                    Rectangle()
                        .fill(entry.weatherCondition.quoteInkColor(isDay: true).opacity(0.3))
                        .frame(width: 22, height: 1)
                    Text(entry.quoteText)
                        .font(.mananaQuote(.body))
                        .foregroundStyle(entry.weatherCondition.quoteInkColor(isDay: true))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                    if let bookTitle = entry.quoteBookTitle {
                        Text("『\(bookTitle)』")
                            .font(.manana(.caption2, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(MananaTheme.clay)
                    }
                    if let author = entry.quoteAuthor {
                        Text(author)
                            .font(.manana(.caption2))
                            .foregroundStyle(MananaTheme.ink.opacity(0.55))
                    }
                    Text(folio)
                        .font(.manana(.caption2))
                        .tracking(1.5)
                        .monospacedDigit()
                        .foregroundStyle(MananaTheme.ink.opacity(0.35))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [MananaTheme.paper.opacity(0), MananaTheme.paper.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    private var folio: String {
        "\(Calendar.current.ordinality(of: .day, in: .year, for: entry.date) ?? 1) / 365"
    }

    @MainActor
    private func renderShareImage() {
        let renderer = ImageRenderer(content: card.frame(width: Self.cardSize.width, height: Self.cardSize.height))
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }
}
