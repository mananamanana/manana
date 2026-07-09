import PencilKit
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

struct MainView: View {
    @EnvironmentObject private var weatherService: WeatherService
    @EnvironmentObject private var quoteService: QuoteService
    @EnvironmentObject private var notificationManager: NotificationManager
    @Environment(\.modelContext) private var modelContext

    @State private var canvasView = PKCanvasView()
    @State private var isErasing = false
    @State private var showArchive = false
    @State private var showSettings = false
    @State private var showAdminTool = false
    @State private var showClearConfirm = false
    @State private var isRefreshingWeather = false
    @State private var contentAppeared = false

    private var todayQuote: Quote? {
        quoteService.quoteForToday(condition: weatherService.condition)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: weatherService.condition.gradientColors(isDay: weatherService.isDay),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.2), value: weatherService.condition)
                .animation(.easeInOut(duration: 1.2), value: weatherService.isDay)

                VStack(spacing: 0) {
                    weatherBadge
                        .padding(.top, 8)

                    locationBanner
                        .padding(.top, 10)

                    Spacer(minLength: 16)

                    paperCanvas
                        .padding(.horizontal, 30)

                    canvasControls
                        .padding(.top, 16)

                    Spacer(minLength: 190)
                }
                .frame(maxHeight: .infinity)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 10)

                quoteSheet
            }
            .overlay(alignment: .topTrailing) {
                dayTab
                    .padding(.top, 130)
                    .offset(x: 14)
                    .opacity(contentAppeared ? 1 : 0)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showArchive = true
                    } label: {
                        Image(systemName: "book.closed")
                    }
                    .accessibilityLabel("보관함 열기")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        #if DEBUG
                        Button {
                            showAdminTool = true
                        } label: {
                            Image(systemName: "text.badge.plus")
                        }
                        .accessibilityLabel("문장 관리 (Dev)")
                        #endif
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("설정 열기")
                    }
                }
            }
            .sheet(isPresented: $showArchive) { ArchiveListView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            #if DEBUG
            .sheet(isPresented: $showAdminTool) {
                QuoteAdminView().environmentObject(quoteService)
            }
            #endif
            .confirmationDialog(
                "오늘 그린 그림을 지울까요?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("전체 지우기", role: .destructive) { clearCanvas() }
                Button("취소", role: .cancel) {}
            }
            .onAppear {
                loadTodayDrawing()
                syncWidgets()
                withAnimation(.easeOut(duration: 0.6)) {
                    contentAppeared = true
                }
            }
            .onChange(of: weatherService.condition) { _, _ in
                upsertTodayEntry()
                refreshNotificationCopy()
                syncWidgets()
            }
            .onChange(of: weatherService.lastUpdated) { _, _ in
                syncWidgets()
            }
        }
    }

    /// A quiet nudge when weather can't be fetched — most often a denied
    /// location permission — instead of silently showing nothing.
    @ViewBuilder
    private var locationBanner: some View {
        if weatherService.temperature == nil, weatherService.lastError != nil {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "location.slash")
                    Text("위치 권한을 허용하면 날씨를 보여줘요")
                }
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .foregroundStyle(MananaTheme.ink.opacity(0.75))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(MananaTheme.paper.opacity(0.85), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var weatherBadge: some View {
        VStack(spacing: 2) {
            HStack(spacing: 10) {
                Text("mañana!")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(MananaTheme.clay)

                Rectangle()
                    .fill(MananaTheme.ink.opacity(0.15))
                    .frame(width: 1, height: 14)

                Text(weatherService.condition.emoji(isDay: weatherService.isDay))
                if let temperature = weatherService.temperature {
                    Text("\(Int(temperature.rounded()))°")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                }
                Text(weatherService.condition.poeticPhrase(isDay: weatherService.isDay))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(MananaTheme.ink.opacity(0.6))
            }
            .foregroundStyle(MananaTheme.ink)
            HStack(spacing: 8) {
                if let feelsLike = weatherService.feelsLike {
                    Text("체감 \(Int(feelsLike.rounded()))°")
                }
                if let high = weatherService.highTemp, let low = weatherService.lowTemp {
                    Text("최고 \(Int(high.rounded()))° / 최저 \(Int(low.rounded()))°")
                }
                if let precipitation = weatherService.precipitationProbability {
                    Text("강수 \(precipitation)%")
                }
            }
            .font(.system(.caption2, design: .rounded))
            .foregroundStyle(MananaTheme.ink.opacity(0.55))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(MananaTheme.paper.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(MananaTheme.ink.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: MananaTheme.ink.opacity(0.15), radius: 10, y: 4)
        .scaleEffect(isRefreshingWeather ? 0.96 : 1)
        .animation(.easeInOut(duration: 0.6), value: weatherService.temperature)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isRefreshingWeather)
        .onTapGesture { refreshWeather() }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(weatherAccessibilityLabel)
        .accessibilityHint("탭하면 날씨를 다시 확인해요")
    }

    private var weatherAccessibilityLabel: String {
        var parts = ["\(weatherService.condition.displayName) 날씨"]
        if let temperature = weatherService.temperature {
            parts.append("현재 \(Int(temperature.rounded()))도")
        }
        return parts.joined(separator: ", ")
    }

    private func refreshWeather() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isRefreshingWeather = true
        weatherService.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isRefreshingWeather = false
        }
    }

    /// The drawing surface itself: a single bounded sheet of paper sitting
    /// on the weather sky, not a full-bleed background — closer to a real
    /// notebook page than a screen tint. Two faint creases suggest a letter
    /// once folded into thirds.
    private var paperCanvas: some View {
        ZStack {
            MananaTheme.paper
            Image(uiImage: Self.paperGrainTile)
                .resizable(resizingMode: .tile)
                .opacity(0.6)
                .blendMode(.multiply)
            GeometryReader { proxy in
                Path { path in
                    for fraction in [1.0 / 3, 2.0 / 3] {
                        let x = proxy.size.width * fraction
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    }
                }
                .stroke(MananaTheme.ink.opacity(0.14), lineWidth: 1)
            }
            DrawingCanvasView(canvasView: $canvasView, isErasing: isErasing) { drawing in
                saveTodayDrawing(drawing)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(MananaTheme.ink.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: MananaTheme.ink.opacity(0.35), radius: 16, y: 10)
    }

    private static let paperGrainTile: UIImage = {
        let size = CGSize(width: 220, height: 220)
        let renderer = ImageRenderer(content: PaperGrain(size: size))
        renderer.scale = UIScreen.main.scale
        renderer.isOpaque = false
        return renderer.uiImage ?? UIImage()
    }()

    /// A small tab peeking off the trailing edge, like a bookmark ribbon
    /// stuck into today's page — taps open the same archive as the toolbar
    /// button, just via a second, more playful affordance.
    private var dayTab: some View {
        Button {
            showArchive = true
        } label: {
            VStack(spacing: 3) {
                Text("\(dayOfYear)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Image(systemName: "book.closed.fill")
                    .font(.caption2)
            }
            .foregroundStyle(MananaTheme.paper)
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .background(MananaTheme.clay, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: MananaTheme.ink.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel("올해 \(dayOfYear)번째 날, 보관함 열기")
    }

    /// The day's quote, presented as a paper sheet pulled up from the
    /// bottom edge — a real card this time, since it's meant to sit above
    /// the drawing rather than print directly onto it.
    private var quoteSheet: some View {
        let inkColor = weatherService.condition.quoteInkColor(isDay: weatherService.isDay)
        return VStack(spacing: 14) {
            Capsule()
                .fill(MananaTheme.ink.opacity(0.15))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            if let quote = todayQuote {
                HStack(spacing: 10) {
                    Text("\(dayOfYear) / 365")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(MananaTheme.clay)
                    ProgressView(value: Double(dayOfYear), total: 365)
                        .tint(MananaTheme.clay)
                }
                .padding(.horizontal, 28)

                Text(quote.text)
                    .font(.system(.body, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(inkColor)
                    .lineSpacing(5)
                    .padding(.horizontal, 26)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.45), value: quote.text)

                if let source = quote.source {
                    Text("— \(source)")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(MananaTheme.ink.opacity(0.45))
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.45), value: source)
                }
            } else {
                Text("문장을 준비 중이에요")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(MananaTheme.ink.opacity(0.7))
                    .padding(.vertical, 20)
            }
        }
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background(
            MananaTheme.paper.opacity(0.97),
            in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
        )
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                .strokeBorder(MananaTheme.ink.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: MananaTheme.ink.opacity(0.25), radius: 20, y: -6)
        .ignoresSafeArea(edges: .bottom)
        .opacity(contentAppeared ? 1 : 0)
        .offset(y: contentAppeared ? 0 : 16)
    }

    private var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
    }

    /// A floating pill of circular tool buttons below the canvas — the
    /// active tool sits in a solid clay circle, matching the day tab's
    /// accent instead of the old dark ink chrome.
    private var canvasControls: some View {
        HStack(spacing: 20) {
            toolButton(systemName: "pencil", isActive: !isErasing) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                isErasing = false
            }
            .accessibilityLabel("펜")

            toolButton(systemName: "eraser", isActive: isErasing) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                isErasing = true
            }
            .accessibilityLabel("지우개")

            toolButton(systemName: "trash", isActive: false) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showClearConfirm = true
            }
            .accessibilityLabel("오늘 그림 전체 지우기")
        }
        .padding(8)
        .background(MananaTheme.paper.opacity(0.95), in: Capsule())
        .overlay(
            Capsule().strokeBorder(MananaTheme.ink.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: MananaTheme.ink.opacity(0.2), radius: 12, y: 6)
    }

    private func toolButton(systemName: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 38, height: 38)
                .foregroundStyle(isActive ? MananaTheme.paper : MananaTheme.ink.opacity(0.7))
                .background(isActive ? MananaTheme.clay : Color.clear, in: Circle())
        }
    }

    private func loadTodayDrawing() {
        let fileName = DrawingStorage.shared.fileName(for: Date())
        canvasView.drawing = DrawingStorage.shared.load(fileName: fileName)
    }

    private func clearCanvas() {
        canvasView.drawing = PKDrawing()
        saveTodayDrawing(canvasView.drawing)
    }

    private func saveTodayDrawing(_ drawing: PKDrawing) {
        let fileName = DrawingStorage.shared.fileName(for: Date())
        DrawingStorage.shared.save(drawing, fileName: fileName)
        upsertTodayEntry(drawingFileName: fileName)
        syncWidgets()
    }

    private func upsertTodayEntry(drawingFileName: String? = nil) {
        let dayKey = DrawingStorage.dateKey(Date())
        let descriptor = FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.dayKey == dayKey })
        let fileName = drawingFileName ?? DrawingStorage.shared.fileName(for: Date())

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.weatherConditionRaw = weatherService.condition.rawValue
            existing.temperature = weatherService.temperature
            if let quote = todayQuote {
                existing.quoteText = quote.text
                existing.quoteSource = quote.source
            }
            existing.drawingFileName = fileName
        } else {
            let quote = todayQuote
            let entry = DiaryEntry(
                date: Date(),
                weatherCondition: weatherService.condition,
                temperature: weatherService.temperature,
                quoteText: quote?.text ?? "",
                quoteSource: quote?.source,
                drawingFileName: fileName
            )
            modelContext.insert(entry)
        }
    }

    private func refreshNotificationCopy() {
        notificationManager.rescheduleForNextOccurrence {
            todayQuote?.text ?? "오늘의 문장을 확인해보세요."
        }
    }

    private func syncWidgets() {
        let quote = todayQuote
        let snapshot = SharedWeatherSnapshot(
            emoji: weatherService.condition.emoji(isDay: weatherService.isDay),
            temperature: weatherService.temperature,
            feelsLike: weatherService.feelsLike,
            highTemp: weatherService.highTemp,
            lowTemp: weatherService.lowTemp,
            precipitationProbability: weatherService.precipitationProbability,
            conditionName: weatherService.condition.displayName,
            backgroundColors: weatherService.condition.gradientHSB(isDay: weatherService.isDay),
            quoteInkColor: weatherService.condition.quoteInkRGB(isDay: weatherService.isDay),
            quoteText: quote?.text ?? "오늘의 문장을 준비 중이에요",
            quoteSource: quote?.source,
            updatedAt: Date()
        )
        SharedWeatherStore.save(snapshot)

        let drawing = canvasView.drawing
        if !drawing.bounds.isEmpty {
            let image = drawing.image(from: drawing.bounds, scale: 2)
            SharedDrawingStore.save(image)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// A tile of cold-press watercolor paper texture — low-frequency mottling,
/// mid-frequency ink fibers, and fine grain "tooth" — rendered once via
/// `ImageRenderer` and tiled. A fixed seed keeps it identical across
/// renders instead of re-rolling (and flickering) every frame.
private struct PaperGrain: View {
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            var rng = SeededGenerator(seed: 42)

            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 18))
                for _ in 0..<16 {
                    let x = CGFloat.random(in: 0...canvasSize.width, using: &rng)
                    let y = CGFloat.random(in: 0...canvasSize.height, using: &rng)
                    let radius = CGFloat.random(in: 30...70, using: &rng)
                    let color: Color = Bool.random(using: &rng)
                        ? Color.white.opacity(0.05)
                        : MananaTheme.ink.opacity(0.04)
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    layer.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }

            for _ in 0..<260 {
                let x = CGFloat.random(in: 0...canvasSize.width, using: &rng)
                let y = CGFloat.random(in: 0...canvasSize.height, using: &rng)
                let length = CGFloat.random(in: 2...7, using: &rng)
                let angle = Double.random(in: 0..<(.pi * 2), using: &rng)
                let opacity = Double.random(in: 0.03...0.09, using: &rng)
                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length))
                context.stroke(path, with: .color(MananaTheme.ink.opacity(opacity)), lineWidth: 0.6)
            }

            for _ in 0..<500 {
                let x = CGFloat.random(in: 0...canvasSize.width, using: &rng)
                let y = CGFloat.random(in: 0...canvasSize.height, using: &rng)
                let radius = CGFloat.random(in: 0.3...0.9, using: &rng)
                let color: Color = Bool.random(using: &rng)
                    ? Color.white.opacity(0.08)
                    : MananaTheme.ink.opacity(0.06)
                let rect = CGRect(x: x, y: y, width: radius, height: radius)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
