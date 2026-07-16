import SwiftUI
import UIKit

/// Mirrors the main screen's own look (full-bleed background art, drawing,
/// left-aligned quote with a dateline) rather than a separately composed
/// "card" — so a past day's detail page and its shared image both read as
/// the same screenshot-style scene as sharing from the live screen does.
struct DiaryEntryDetailView: View {
    let entry: DiaryEntry

    @State private var shareImage: UIImage?
    /// The full screen size, used for both the live scene and the shared
    /// image so they always match exactly. A GeometryReader here measured
    /// the safe-area-respecting size instead (nav bar/home indicator insets
    /// carved out) — visibly smaller than the true screen height — which
    /// clipped the bottom of the quote once it ran more than a couple lines.
    private var sceneSize: CGSize { UIScreen.main.bounds.size }

    private static var backgroundImageCache: [WeatherBackground: UIImage] = [:]

    private var background: WeatherBackground {
        WeatherBackground(condition: entry.weatherCondition)
    }

    /// Entries don't record whether it was day or night when they were
    /// made, so this assumes day — the same assumption the old card view
    /// made for its gradient and ink color.
    private var quoteInkColor: Color {
        entry.weatherCondition.quoteInkColor(isDay: true)
    }

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yy.M.d(EEE)"
        return formatter.string(from: entry.date)
    }

    private var byline: String? {
        let parts = [entry.quoteBookTitle.map { "『\($0)』" }, entry.quoteAuthor].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    var body: some View {
        scene(size: sceneSize)
        .ignoresSafeArea()
        .navigationTitle(entry.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // In the nav bar rather than overlaid on the scene — an overlay
            // at a fixed bottom position risked covering the quote text
            // whenever it ran long enough to reach that far down.
            ToolbarItem(placement: .topBarTrailing) {
                shareButton
            }
        }
        .sheet(isPresented: Binding(
            get: { shareImage != nil },
            set: { isPresented in if !isPresented { shareImage = nil } }
        )) {
            if let shareImage {
                ActivityView(activityItems: [shareImage])
            }
        }
    }

    /// The whole visible scene — background, drawing, quote — parameterized
    /// by size so the live body and `renderShareImage()` render the exact
    /// same view instead of one trying to photograph the other.
    private func scene(size: CGSize) -> some View {
        ZStack {
            backgroundArt

            // Drawing and quote grouped into one VStack, centered together
            // with a Spacer above and below — rather than the drawing
            // floating whereever it naturally sits (usually near the top)
            // while the quote pins to the very bottom, leaving a large,
            // ungainly gap between them.
            VStack(spacing: 28) {
                Spacer(minLength: 0)

                // Cropped to just the ink (not the full, mostly-empty
                // canvas) so a small doodle doesn't drag along a huge
                // transparent margin that would otherwise reopen the same
                // gap this grouping is trying to close.
                if let uiImage = DrawingStorage.shared.tightImage(fileName: entry.drawingFileName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: size.width * 0.7, maxHeight: size.height * 0.35)
                }

                quoteBlock

                Spacer(minLength: 0)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private var backgroundArt: some View {
        if let uiImage = Self.backgroundUIImage(for: background) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(
                colors: entry.weatherCondition.gradientColors(isDay: true),
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var quoteBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dateLine)
                .font(.manana(size: 20, weight: .semibold))
                .foregroundStyle(quoteInkColor.opacity(0.55))
                .shadow(color: MananaTheme.paper.opacity(0.5), radius: 2, y: 1)

            Text(entry.quoteText)
                .font(.manana(size: 29, weight: .semibold))
                .multilineTextAlignment(.leading)
                .foregroundStyle(quoteInkColor)
                .shadow(color: MananaTheme.paper.opacity(0.5), radius: 4, y: 1)
                .lineSpacing(6)

            if let byline {
                Text(byline)
                    .font(.manana(size: 19))
                    .foregroundStyle(quoteInkColor.opacity(0.75))
                    .shadow(color: MananaTheme.paper.opacity(0.5), radius: 3, y: 1)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func backgroundUIImage(for background: WeatherBackground) -> UIImage? {
        if let cached = backgroundImageCache[background] { return cached }
        guard let url = Bundle.main.url(forResource: background.imageName, withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path)
        else { return nil }
        backgroundImageCache[background] = image
        return image
    }

    private var shareButton: some View {
        Button {
            shareImage = renderShareImage()
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel("공유하기")
    }

    @MainActor
    private func renderShareImage() -> UIImage? {
        let renderer = ImageRenderer(content: scene(size: sceneSize))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
