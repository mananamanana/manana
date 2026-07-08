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
                VStack(spacing: 6) {
                    Text(entry.quoteText)
                        .font(.system(.body, design: .serif))
                        .multilineTextAlignment(.center)
                    if let source = entry.quoteSource {
                        Text("— \(source)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding()
            }
        }
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
