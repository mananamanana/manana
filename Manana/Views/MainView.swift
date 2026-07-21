import PencilKit
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

struct MainView: View {
    @EnvironmentObject private var weatherService: WeatherService
    @EnvironmentObject private var quoteService: QuoteService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var canvasView = PKCanvasView()
    @State private var canUndo = false
    @State private var isErasing = false
    @State private var showToolPanel = false
    @State private var showColorPicker = false
    @State private var selectedColor: Color = .black
    @State private var showArchive = false
    @State private var shareImage: UIImage?
    /// Hides the weather badge and floating buttons for the moment it takes
    /// to snapshot the screen, so the shared image is just the drawing and
    /// quote rather than every bit of on-screen chrome.
    @State private var isCapturingShare = false
    @State private var isRefreshingWeather = false
    @State private var isWeatherExpanded = false
    @State private var contentAppeared = false
    @State private var displayedQuoteText = ""
    @State private var showByline = false
    @State private var quoteTypewriterTask: Task<Void, Never>?
    /// 0 = today, -1 = yesterday, +1 = tomorrow (capped there — see
    /// `navigateDay(by:)`).
    @State private var dayOffset = 0
    /// KST calendar day the app currently thinks is "today" — compared
    /// against the real KST date each minute (and on foreground) to detect
    /// midnight passing while the app is open, so today's page can archive
    /// and hand off to the new day automatically.
    @State private var currentDayKey = ""
    /// Every temperature reading seen today, so the day's record can be
    /// saved as an average rather than whatever the last live reading
    /// happened to be.
    @State private var todayTemperatureSamples: [Double] = []

    private static let paletteColors: [Color] = [.black, .red, .yellow, .green, .blue, .white]
    /// Fixed rather than derived from the quote text's live height — that
    /// used to make the box visibly shrink while the quote was still being
    /// typed out (its measured height grew with every new character/line),
    /// so the badge kept resizing under the user's eyes. Sized against the
    /// real content (location + big temperature + hourly strip) so the
    /// bottom padding roughly matches the top, rather than being measured
    /// against a mock that was missing the temperature row.
    private static let expandedBadgeHeight: CGFloat = 312

    private var todayQuote: Quote? {
        quoteService.quoteForToday(condition: weatherService.condition)
    }

    // MARK: - Day navigation (swipe left/right on the quote to browse past days)

    private var displayedDate: Date {
        Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
    }

    private var isViewingToday: Bool { dayOffset == 0 }

    /// One step past today — a placeholder page rather than real content,
    /// since there's obviously nothing recorded yet. Navigation is capped
    /// here; there's no point going further into the future than that.
    private var isFuture: Bool { dayOffset > 0 }

    /// The saved diary entry for whatever past day is currently displayed —
    /// nil when viewing today (live data is used instead) or when that day
    /// simply has no record.
    private var pastEntry: DiaryEntry? {
        guard !isViewingToday else { return nil }
        let dayKey = DrawingStorage.dateKey(displayedDate)
        let descriptor = FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.dayKey == dayKey })
        return try? modelContext.fetch(descriptor).first
    }

    private var displayedCondition: WeatherCondition? {
        isViewingToday ? weatherService.condition : pastEntry?.weatherCondition
    }

    private var displayedTemperature: Double? {
        isViewingToday ? weatherService.temperature : pastEntry?.temperature
    }

    private var displayedConditionLabel: String {
        if isViewingToday {
            return weatherService.backgroundCondition.displayLabel
        }
        return displayedCondition?.displayName ?? "기록 없음"
    }

    /// Past entries only ever stored the coarse `WeatherCondition` (not the
    /// finer `WeatherBackground`), so this maps back to the closest
    /// background art for that day.
    private var displayedBackground: WeatherBackground {
        guard !isViewingToday else { return weatherService.backgroundCondition }
        guard let condition = displayedCondition else { return weatherService.backgroundCondition }
        return WeatherBackground(condition: condition)
    }

    /// Shared by the drag-to-expand gesture and the chevron's own tap
    /// target — either way, an already-open pen/eraser panel shouldn't
    /// linger uselessly once drawing is disabled by the expanded box (see
    /// paperCanvas/drawTools below).
    private func expandWeatherBadge() {
        isWeatherExpanded = true
        showToolPanel = false
        showColorPicker = false
    }

    private func navigateDay(by delta: Int) {
        let newOffset = min(1, dayOffset + delta)
        guard newOffset != dayOffset else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            dayOffset = newOffset
            isWeatherExpanded = false
        }
        if isViewingToday {
            loadTodayDrawing()
        }
    }

    /// Whatever the quote block should be typing out right now — today's
    /// live quote, a past day's saved one, or one of the placeholder
    /// messages (no record / preparing / future) — so the same typewriter
    /// mechanic covers every day, not just today.
    private var currentDisplayText: String {
        if let info = displayedQuoteInfo { return info.text }
        if isViewingToday { return "문장을 준비 중이에요" }
        if isFuture { return Self.futurePlaceholderText }
        return "이 날은 기록이 없어요"
    }

    /// Seeds a fixed entry for yesterday so the swipe-back gesture has
    /// something to show the very first time, since there's no historical
    /// weather API wired up — only whatever the app itself has saved.
    private func seedYesterdayEntryIfNeeded() {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return }
        let dayKey = DrawingStorage.dateKey(yesterday)
        let descriptor = FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.dayKey == dayKey })
        guard (try? modelContext.fetch(descriptor).first) == nil else { return }

        // KMA has no accessible historical-observation API with this app's
        // current key (a real lookup returned 403 — that endpoint needs its
        // own separate 활용신청 on data.go.kr), so this is a plausible
        // stand-in for Seoul in July rather than the real recorded weather.
        let entry = DiaryEntry(
            date: yesterday,
            weatherCondition: .rain,
            temperature: 26,
            // Broken at clause boundaries (subject/verb groups) rather than
            // left to width-based auto-wrap, for the same reason as
            // `futurePlaceholderText` above.
            quoteText: "어떤 나라에 '눈사람 택배'라는 게 있다 하네요\n눈이 내리지 않는 남쪽 지방으로\n북쪽 지방 눈사람을 특수포장해 보낸다 해요",
            quoteBookTitle: "최선은 그런 것이에요",
            quoteAuthor: "이규리",
            drawingFileName: DrawingStorage.shared.fileName(for: yesterday)
        )
        modelContext.insert(entry)
    }

    /// Checked on appear, on a repeating timer, and whenever the app comes
    /// back to the foreground — so crossing midnight KST while the app is
    /// open (or was merely backgrounded over it) reliably archives the day
    /// that just ended and snaps the page back to the new "today", instead
    /// of silently continuing to show yesterday's now-stale live data.
    private func checkForDayRollover() {
        let newDayKey = DrawingStorage.dateKey(Date())
        guard !currentDayKey.isEmpty else {
            currentDayKey = newDayKey
            return
        }
        guard newDayKey != currentDayKey else { return }

        finalizeDayEntry(dayKey: currentDayKey)
        currentDayKey = newDayKey
        todayTemperatureSamples.removeAll()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            dayOffset = 0
            isWeatherExpanded = false
        }
        loadTodayDrawing()
        syncWidgets()
        typeOutQuote(currentDisplayText)
    }

    /// Replaces the day's stored temperature with the average of every
    /// reading collected while it was "today", so the permanent record
    /// reflects the whole day rather than whatever the last live reading
    /// happened to be at the moment it rolled over.
    private func finalizeDayEntry(dayKey: String) {
        guard !todayTemperatureSamples.isEmpty else { return }
        let average = todayTemperatureSamples.reduce(0, +) / Double(todayTemperatureSamples.count)
        let descriptor = FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.dayKey == dayKey })
        guard let entry = try? modelContext.fetch(descriptor).first else { return }
        entry.temperature = average
    }

    /// Loose bundled JPEGs (Resources/Backgrounds), not an asset catalog —
    /// loaded via `Bundle.main` rather than `Image(_:)` so lookup doesn't
    /// depend on asset-catalog-vs-loose-file name resolution, and cached
    /// since each is a multi-megapixel decode.
    private static var backgroundImageCache: [WeatherBackground: UIImage] = [:]

    private static func backgroundUIImage(for background: WeatherBackground) -> UIImage? {
        if let cached = backgroundImageCache[background] { return cached }
        guard let url = Bundle.main.url(forResource: background.imageName, withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path)
        else { return nil }
        backgroundImageCache[background] = image
        return image
    }

    @ViewBuilder
    private var backgroundArt: some View {
        if let uiImage = Self.backgroundUIImage(for: displayedBackground) {
            // `.scaledToFill()` alone doesn't reliably claim the full
            // screen the way `LinearGradient` does — without an explicit
            // infinite frame it can size to something smaller, which was
            // throwing off every sibling's safe-area layout (the weather
            // badge was rendering up into the status bar).
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(
                colors: (displayedCondition ?? weatherService.condition).gradientColors(isDay: weatherService.isDay),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                weatherBadge
                    .padding(.top, 10)
                    // Hidden for the share snapshot in the compact state
                    // (just drawing + quote), but kept visible when the box
                    // is pulled open — the user wants weather included in
                    // the shared image specifically when it's expanded.
                    .opacity(isCapturingShare && !showExpandedBadge ? 0 : 1)

                locationBanner
                    .padding(.top, 10)
                    .opacity(isCapturingShare && !showExpandedBadge ? 0 : 1)

                Spacer(minLength: 16)

                paperCanvas

                Spacer(minLength: 40)
            }
            .frame(maxHeight: .infinity)
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 10)
            // A dedicated `.background(content:)` (rather than a ZStack
            // sibling with its own `.ignoresSafeArea()`) so the full-bleed
            // art doesn't grow the container's frame and throw off how the
            // weather badge above accounts for the safe area — background
            // content is always sized to match the foreground, regardless
            // of its own ignoresSafeArea.
            .background {
                backgroundArt
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.2), value: displayedBackground)
            }
            .overlay(alignment: showExpandedBadge ? .top : .bottom) {
                quoteSheet
                    // Anchored a fixed distance below the badge (its own
                    // 10pt top padding + its fixed height + a small gap)
                    // instead of vertically centered in the whole stage —
                    // centering depended on the badge's height matching the
                    // quote's measured position, which broke once the badge
                    // height became a flat constant instead of derived.
                    .padding(.top, showExpandedBadge ? 10 + Self.expandedBadgeHeight + 20 : 0)
                    .padding(.bottom, showExpandedBadge ? 0 : 40)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showExpandedBadge)
            }
            .overlay(alignment: .bottomTrailing) {
                drawTools
                    .padding(.trailing, 20)
                    .padding(.bottom, 40)
                    .opacity(contentAppeared && !isCapturingShare ? 1 : 0)
            }
            .sheet(isPresented: $showArchive) { ArchiveListView() }
            .sheet(isPresented: Binding(
                get: { shareImage != nil },
                set: { isPresented in if !isPresented { shareImage = nil } }
            )) {
                if let shareImage {
                    ActivityView(activityItems: [shareImage])
                }
            }
            .onAppear {
                checkForDayRollover()
                seedYesterdayEntryIfNeeded()
                loadTodayDrawing()
                syncWidgets()
                withAnimation(.easeOut(duration: 0.6)) {
                    contentAppeared = true
                }
                typeOutQuote(currentDisplayText)
            }
            .onChange(of: weatherService.condition) { _, _ in
                upsertTodayEntry()
                syncWidgets()
            }
            .onChange(of: weatherService.lastUpdated) { _, _ in
                syncWidgets()
            }
            // Not gated on `isViewingToday` — the live weather service keeps
            // refreshing in the background regardless of which page is on
            // screen, and every real reading should count toward today's
            // average, whether or not the user happens to be looking at it.
            .onChange(of: weatherService.temperature) { _, newValue in
                guard let newValue else { return }
                todayTemperatureSamples.append(newValue)
            }
            .onChange(of: todayQuote?.text) { _, _ in
                guard isViewingToday else { return }
                typeOutQuote(currentDisplayText)
            }
            // Covers every day change — swiping to a past day, the future
            // placeholder, or back to today — so the same handwritten
            // reveal + haptic ticks plays no matter which page it lands on.
            .onChange(of: dayOffset) { _, _ in
                typeOutQuote(currentDisplayText)
            }
            // Detects midnight KST passing while the app is open.
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                checkForDayRollover()
            }
            // Detects it having passed while the app was backgrounded.
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    checkForDayRollover()
                }
            }
        }
    }

    /// A quiet nudge when weather can't be fetched — shows the real reason
    /// (denied location, network/API error, etc.) instead of a fixed guess,
    /// and routes the tap to the OS Settings app to fix location access.
    @ViewBuilder
    private var locationBanner: some View {
        if weatherService.temperature == nil, let message = weatherService.lastError {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                    Text(message)
                }
                .font(.manana(.caption2, weight: .medium))
                .foregroundStyle(MananaTheme.paper.opacity(0.9))
                .shadow(color: MananaTheme.ink.opacity(0.3), radius: 4, y: 1)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
        }
    }

    /// A floating pill bar, not stuck edge-to-edge — exactly two sizes.
    /// Collapsed (default) is the compact emoji/temp/phrase row. Dragging
    /// down (or tapping the chevron) grows it into an Apple Weather–style
    /// panel: location + condition icon, big temp with condition/high-low,
    /// and an hourly strip — matching the reference layout the user shared.
    /// Expansion only makes sense on today's live data — past entries don't
    /// carry location/high-low/hourly detail — so it's forced closed
    /// whenever the displayed day isn't today (see `navigateDay(by:)`).
    private var showExpandedBadge: Bool { isWeatherExpanded && isViewingToday }

    private var weatherBadge: some View {
        Group {
            if showExpandedBadge {
                expandedWeatherContent
            } else {
                compactWeatherContent
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, showExpandedBadge ? 28 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: showExpandedBadge ? Self.expandedBadgeHeight : nil, alignment: .top)
        // Hand-illustrated frame (transparent middle) instead of a filled
        // card — same idea as the ✏️/📔/⚙️ buttons — so the background art
        // reads through clearly instead of being covered by an opaque plate.
        .background(
            Image(showExpandedBadge ? "BigBox" : "MiniBox")
                .resizable()
        )
        .padding(.horizontal, 16)
        // Since the fill is gone (just an outline now), the empty middle of
        // the box wouldn't otherwise register taps/drags at all — only the
        // stroke line and the text glyphs would. This makes the whole box
        // tappable/draggable again, matching its visible bounds.
        .contentShape(Rectangle())
        .scaleEffect(isRefreshingWeather ? 0.98 : 1, anchor: .top)
        .animation(.easeInOut(duration: 0.6), value: weatherService.temperature)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isRefreshingWeather)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showExpandedBadge)
        .onTapGesture {
            guard isViewingToday else { return }
            refreshWeather()
        }
        .gesture(
            DragGesture(minimumDistance: 15)
                .onEnded { value in
                    guard isViewingToday else { return }
                    if value.translation.height > 15 {
                        expandWeatherBadge()
                    } else if value.translation.height < -15 {
                        isWeatherExpanded = false
                    }
                }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(weatherAccessibilityLabel)
        .accessibilityHint(isViewingToday ? "탭하면 날씨를 다시 확인해요. 아래로 내리면 더 크게 봐요" : "지난 날의 기록이에요")
    }

    private var compactWeatherContent: some View {
        HStack(spacing: 10) {
            if displayedCondition != nil {
                WeatherIcon(name: displayedBackground.iconName)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(MananaTheme.ink.opacity(0.8))
                if let temperature = displayedTemperature {
                    Text("\(Int(temperature.rounded()))°")
                        .font(.manana(size: 17, weight: .semibold))
                }
                Text(displayedConditionLabel)
                    .font(.manana(size: 13))
                    .foregroundStyle(MananaTheme.ink.opacity(0.65))
            } else {
                Text(isFuture ? "mañana!" : "기록이 없어요")
                    .font(.manana(size: 13))
                    .foregroundStyle(MananaTheme.ink.opacity(0.5))
            }

            Spacer(minLength: 8)

            if isViewingToday {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MananaTheme.ink.opacity(0.4))
                    // A bit of extra padding around the small glyph so
                    // there's an actually comfortable tap target, not just
                    // the icon's own tight bounds.
                    .padding(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        expandWeatherBadge()
                    }
            }
        }
        .foregroundStyle(MananaTheme.ink)
    }

    /// Mirrors the reference screenshot: location (top-left) with the
    /// condition symbol (top-right), a big temperature with the condition
    /// name and high/low stacked on the right, then an hourly strip.
    private var expandedWeatherContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 4) {
                    Text(weatherService.locationName ?? "위치 확인 중")
                        .font(.manana(size: 15, weight: .semibold))
                    Image(systemName: "location.fill")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(MananaTheme.ink.opacity(0.85))

                Spacer(minLength: 8)

                WeatherIcon(name: weatherService.backgroundCondition.iconName)
                    .frame(width: 58, height: 58)
                    .foregroundStyle(MananaTheme.ink.opacity(0.8))
            }

            HStack(alignment: .top, spacing: 8) {
                if let temperature = weatherService.temperature {
                    Text("\(Int(temperature.rounded()))°")
                        .font(.manana(size: 52, weight: .semibold))
                        .foregroundStyle(MananaTheme.ink)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(weatherService.condition.displayName)
                    if let high = weatherService.highTemp, let low = weatherService.lowTemp {
                        Text("최고:\(Int(high.rounded()))° 최저:\(Int(low.rounded()))°")
                    }
                }
                .font(.manana(.subheadline))
                .foregroundStyle(MananaTheme.ink.opacity(0.7))
                .padding(.top, 6)
            }

            if !weatherService.hourlyForecast.isEmpty {
                HStack(spacing: 0) {
                    ForEach(weatherService.hourlyForecast) { hour in
                        VStack(spacing: 8) {
                            Text(hour.hourLabel)
                                .font(.manana(.caption2))
                                .foregroundStyle(MananaTheme.ink.opacity(0.6))
                            WeatherIcon(name: WeatherBackground(condition: hour.condition).iconName)
                                .frame(width: 28, height: 28)
                                .foregroundStyle(MananaTheme.ink.opacity(0.8))
                            Text("\(hour.temperature)°")
                                .font(.manana(.footnote, weight: .medium))
                                .foregroundStyle(MananaTheme.ink)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        // Mirrors the compact box's own chevron — same tap target styling,
        // just pointing the other way and living bottom-trailing here so it
        // doesn't collide with the hourly strip above it.
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "chevron.up")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MananaTheme.ink.opacity(0.4))
                .padding(8)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isWeatherExpanded = false
                    }
                }
                .accessibilityLabel("날씨 박스 접기")
        }
    }

    private var weatherAccessibilityLabel: String {
        guard let condition = displayedCondition else { return "날씨 기록 없음" }
        var parts = ["\(condition.displayName) 날씨"]
        if let temperature = displayedTemperature {
            parts.append("\(isViewingToday ? "현재" : "그날") \(Int(temperature.rounded()))도")
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

    /// Reveals the quote a character at a time, like it's being handwritten,
    /// with a light haptic tick per character — starts once the rest of the
    /// screen has finished its own fade-in, and the byline fades in after.
    /// The "미래가 아직 도착하지 않았어요" placeholder reads better a bit
    /// faster than a real quote — it's much longer, so the standard 110ms
    /// pace makes it drag.
    // Broken at sentence boundaries rather than left to width-based
    // auto-wrap, so it always reads as three clean lines instead of
    // wherever the screen happens to cut it off.
    private static let futurePlaceholderText = "mañana!는 에스파냐어로\n내일 또는 아침이라고 불립니다.\n우리는 늘 도착하지 않은 미래에 걱정하지 않은가요?\n오늘부터는 한 문장을 기다리며\n여유롭고 낙천적으로 살아요."

    private func typeOutQuote(_ text: String) {
        quoteTypewriterTask?.cancel()
        displayedQuoteText = ""
        showByline = false
        guard !text.isEmpty else { return }

        let charDelay: UInt64 = text == Self.futurePlaceholderText ? 85_000_000 : 110_000_000

        quoteTypewriterTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }

            let feedback = UISelectionFeedbackGenerator()
            feedback.prepare()
            for character in text {
                try? await Task.sleep(nanoseconds: charDelay)
                guard !Task.isCancelled else { return }
                displayedQuoteText.append(character)
                feedback.selectionChanged()
            }

            try? await Task.sleep(nanoseconds: charDelay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                showByline = true
            }
        }
    }

    /// The drawing surface — no bordered paper rectangle, no texture, just
    /// the canvas open directly over the weather sky, matching the
    /// reference app's plain full-bleed drawing area. Past days show a
    /// read-only render of that day's saved drawing instead — swapping the
    /// live `PKCanvasView`'s content back and forth risked bleeding one
    /// day's edits into another's saved file.
    private var paperCanvas: some View {
        GeometryReader { proxy in
            Group {
                if isViewingToday {
                    DrawingCanvasView(
                        canvasView: $canvasView,
                        canUndo: $canUndo,
                        isErasing: isErasing,
                        inkColor: UIColor(selectedColor)
                    ) { drawing in
                        saveTodayDrawing(drawing)
                    }
                    // No drawing while the weather box is pulled open — the
                    // layout barely leaves room for the canvas at that point
                    // anyway.
                    .allowsHitTesting(!showExpandedBadge)
                } else if let entry = pastEntry,
                          // Rendered at this exact same size the live canvas
                          // occupies (rather than a fixed square) — otherwise
                          // the drawing only fills the square's top-left
                          // corner at the wrong aspect ratio, and scaling
                          // that to fit the real portrait frame makes it look
                          // small and shifted left.
                          let uiImage = DrawingStorage.shared.image(fileName: entry.drawingFileName, size: proxy.size) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    Color.clear
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    /// Captures the actual on-screen pixels (whatever's currently visible —
    /// weather box, drawing, quote, buttons) rather than recomposing a
    /// separate flattened card, so what's shared matches what was seen.
    @MainActor
    private func renderShareImage() -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        else { return nil }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    /// A single pencil button that expands into a small pen/eraser/undo
    /// stack. Colors are a second, nested reveal — tapping the pen again
    /// slides out the 5-swatch palette instead of showing it up front.
    private var drawTools: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if showToolPanel && isViewingToday && !showExpandedBadge {
                VStack(spacing: 10) {
                    if showColorPicker {
                        VStack(spacing: 6) {
                            ForEach(Self.paletteColors, id: \.self) { color in
                                Button {
                                    selectedColor = color
                                    isErasing = false
                                } label: {
                                    Image(paletteCrayonImageName(for: color))
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .background(
                                            // Faint circle so the white swatch (barely visible
                                            // ink on paper) still reads as a tappable chip.
                                            Circle()
                                                .strokeBorder(MananaTheme.ink.opacity(0.15), lineWidth: 1)
                                                .padding(-2)
                                        )
                                        .overlay(
                                            Circle()
                                                .strokeBorder(MananaTheme.clay, lineWidth: 2)
                                                .padding(-4)
                                                .opacity(!isErasing && selectedColor == color ? 1 : 0)
                                        )
                                }
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        Rectangle()
                            .fill(MananaTheme.ink.opacity(0.12))
                            .frame(width: 20, height: 1)
                    }

                    drawToolButton("IconPen", isActive: !isErasing, tint: selectedColor == .white ? nil : selectedColor) {
                        isErasing = false
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            showColorPicker.toggle()
                        }
                    }
                    .accessibilityLabel("펜, 다시 누르면 색상 선택")

                    drawToolButton("IconEraser", isActive: isErasing) {
                        isErasing = true
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            showColorPicker = false
                        }
                    }
                    .accessibilityLabel("지우개")

                    drawToolButton("IconUndo", isActive: false) {
                        canvasView.undoManager?.undo()
                    }
                    .accessibilityLabel("실행 취소")
                    .disabled(!canUndo)
                    .opacity(canUndo ? 1 : 0.35)
                }
                .transition(.scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity))
            }

            if isViewingToday && !showExpandedBadge {
                sketchCrayonButton(tint: selectedColor == .white ? nil : selectedColor) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showToolPanel.toggle()
                        if !showToolPanel { showColorPicker = false }
                    }
                }
                .accessibilityLabel(showToolPanel ? "그리기 도구 닫기" : "그리기 도구 열기")
            }

            sketchButton("IconCalendar") {
                showArchive = true
            }
            .accessibilityLabel("보관함 열기")

            sketchButton("IconShare") {
                isCapturingShare = true
                Task { @MainActor in
                    // A beat for SwiftUI to actually redraw with the badge
                    // and buttons hidden before the snapshot is taken.
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    shareImage = renderShareImage()
                    isCapturingShare = false
                }
            }
            .accessibilityLabel("오늘의 기록 공유하기")
        }
    }

    /// Maps a palette color to its pre-colored hand-drawn crayon-stroke
    /// asset (e.g. "IconCrayonRed") used in the color picker swatches.
    private func paletteCrayonImageName(for color: Color) -> String {
        switch color {
        case .red: return "IconCrayonRed"
        case .yellow: return "IconCrayonYellow"
        case .green: return "IconCrayonGreen"
        case .blue: return "IconCrayonBlue"
        case .white: return "IconCrayonWhite"
        default: return "IconCrayonBlack"
        }
    }

    /// A hand-drawn-looking control: just the hand-drawn icon itself (from
    /// Assets.xcassets, e.g. "IconCrayon") — no outline or card behind it,
    /// so it reads as a doodle directly on the sketchbook background. `tint`,
    /// when given, recolors the icon via template rendering (e.g. IconCrayon
    /// matching the currently selected ink color); nil keeps the artwork's
    /// own colors.
    private func sketchButton(_ imageName: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .renderingMode(tint == nil ? .original : .template)
                .scaledToFit()
                .frame(width: 36, height: 36)
                .frame(width: 48, height: 48)
                .foregroundStyle(tint ?? MananaTheme.ink)
                .shadow(color: MananaTheme.paper.opacity(0.6), radius: 2, y: 1)
                .contentShape(Rectangle())
        }
    }

    /// The crayon toggle button, like `sketchButton` but with an extra
    /// "IconCrayonFill" layer behind the linework — a solid silhouette of
    /// just the tip's enclosed window (the one area in the artwork fully
    /// closed off by ink on every side). Tinting only the outline leaves
    /// that window empty/see-through, so a selected ink color reads as a
    /// colored outline around a hole rather than a filled-in crayon tip;
    /// the fill layer solves that without touching the body/legs, which
    /// have no enclosed area and stay linework-only same as before.
    private func sketchCrayonButton(tint: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if let tint {
                    Image("IconCrayonFill")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(tint)
                }
                Image("IconCrayon")
                    .resizable()
                    .renderingMode(tint == nil ? .original : .template)
                    .scaledToFit()
                    .foregroundStyle(tint ?? MananaTheme.ink)
            }
            .frame(width: 36, height: 36)
            .frame(width: 48, height: 48)
            .shadow(color: MananaTheme.paper.opacity(0.6), radius: 2, y: 1)
            .contentShape(Rectangle())
        }
    }

    /// Same treatment as `sketchButton`: just the hand-drawn icon, no card
    /// or circle behind it. Active/inactive is shown with opacity alone
    /// now that the tinted circle background is gone. `tint`, when given,
    /// recolors the icon (e.g. the pen matching the currently selected ink
    /// color) via template rendering; nil keeps the artwork's own colors.
    private func drawToolButton(_ imageName: String, isActive: Bool, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .renderingMode(tint == nil ? .original : .template)
                .scaledToFit()
                .frame(width: 30, height: 30)
                .frame(width: 40, height: 40)
                .foregroundStyle(tint ?? MananaTheme.ink)
                .opacity(isActive ? 1 : 0.5)
                .shadow(color: MananaTheme.paper.opacity(0.6), radius: 2, y: 1)
                .contentShape(Rectangle())
        }
    }

    /// The hand-painted backgrounds are uniformly light/pastel (unlike the
    /// old programmatic gradients, which went dark for night/storm moods),
    /// so the quote reads in dark, mood-tinted ink with a soft light lift
    /// instead of light cream text.
    private var quoteInkColor: Color {
        (displayedCondition ?? weatherService.condition).quoteInkColor(isDay: weatherService.isDay)
    }

    /// A small dateline above the quote — reads like the date stamp at the
    /// top of a diary entry, tying the displayed page to the calendar
    /// archive. Follows `displayedDate`, so it reads "26.7.9(목)" etc. when
    /// swiped back to a past day.
    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yy.M.d(EEE)"
        return formatter.string(from: displayedDate)
    }

    /// Today's quote comes from the live typewriter reveal; a past day's
    /// comes straight from its saved `DiaryEntry`, shown immediately.
    private var displayedQuoteInfo: (text: String, bookTitle: String?, author: String?)? {
        if isViewingToday {
            guard let quote = todayQuote else { return nil }
            return (quote.text, quote.bookTitle, quote.author)
        }
        guard let entry = pastEntry else { return nil }
        return (entry.quoteText, entry.quoteBookTitle, entry.quoteAuthor)
    }

    /// The day's quote, printed straight onto the weather background — no
    /// card, no paper backing — so it reads as part of the same scene
    /// instead of a separate sheet floating on top. Bold, oversized cream
    /// type with a soft ink shadow keeps it legible over any gradient.
    private var quoteSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dateLine)
                .font(.manana(size: 20, weight: .semibold))
                .foregroundStyle(quoteInkColor.opacity(0.55))
                .shadow(color: MananaTheme.paper.opacity(0.5), radius: 2, y: 1)

            if let info = displayedQuoteInfo {
                Text(displayedQuoteText)
                    .font(.manana(size: 29, weight: .semibold))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(quoteInkColor)
                    .shadow(color: MananaTheme.paper.opacity(0.5), radius: 4, y: 1)
                    .lineSpacing(6)

                if showByline, let byline = byline(bookTitle: info.bookTitle, author: info.author) {
                    Text(byline)
                        .font(.manana(size: 19))
                        .foregroundStyle(quoteInkColor.opacity(0.75))
                        .shadow(color: MananaTheme.paper.opacity(0.5), radius: 3, y: 1)
                        .transition(.opacity)
                }
            } else {
                Text(displayedQuoteText)
                    .font(.manana(size: 19))
                    .foregroundStyle(quoteInkColor.opacity(0.85))
                    .shadow(color: MananaTheme.paper.opacity(0.5), radius: 3, y: 1)
                    .padding(.vertical, 20)
            }
        }
        .padding(.leading, 26)
        // Wider trailing inset than the leading side — keeps long lines
        // from running under the ✏️/📔/⚙️ button column at the bottom-right.
        .padding(.trailing, 96)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(contentAppeared ? 1 : 0)
        .offset(y: contentAppeared ? 0 : 16)
        // No fill behind the text, so — same as the weather badge — the
        // hit area has to be claimed explicitly for the swipe-day gesture
        // to register anywhere across the block, not just on the glyphs.
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < -40 {
                        navigateDay(by: 1)
                    } else if value.translation.width > 40 {
                        navigateDay(by: -1)
                    }
                }
        )
    }

    private func byline(bookTitle: String?, author: String?) -> String? {
        let parts = [bookTitle.map { "『\($0)』" }, author].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func loadTodayDrawing() {
        let fileName = DrawingStorage.shared.fileName(for: Date())
        canvasView.drawing = DrawingStorage.shared.load(fileName: fileName)
        // Loading a saved drawing shouldn't itself count as an undoable
        // step — undo should only appear once the user actually draws
        // something new this session.
        canvasView.undoManager?.removeAllActions()
        canUndo = false
        selectedColor = weatherService.isDay ? .black : .white
    }

    private func saveTodayDrawing(_ drawing: PKDrawing) {
        let fileName = DrawingStorage.shared.fileName(for: Date())
        DrawingStorage.shared.save(drawing, fileName: fileName)
        upsertTodayEntry(drawingFileName: fileName)
        syncWidgets()
    }

    /// The running average of today's temperature readings so far — falls
    /// back to the live reading if no samples have accumulated yet (e.g.
    /// right at launch, before the first one lands).
    private var averageTemperatureSoFar: Double? {
        guard !todayTemperatureSamples.isEmpty else { return weatherService.temperature }
        return todayTemperatureSamples.reduce(0, +) / Double(todayTemperatureSamples.count)
    }

    private func upsertTodayEntry(drawingFileName: String? = nil) {
        let dayKey = DrawingStorage.dateKey(Date())
        let descriptor = FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.dayKey == dayKey })
        let fileName = drawingFileName ?? DrawingStorage.shared.fileName(for: Date())

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.weatherConditionRaw = weatherService.condition.rawValue
            existing.temperature = averageTemperatureSoFar
            if let quote = todayQuote {
                existing.quoteText = quote.text
                existing.quoteBookTitle = quote.bookTitle
                existing.quoteAuthor = quote.author
            }
            existing.drawingFileName = fileName
        } else {
            let quote = todayQuote
            let entry = DiaryEntry(
                date: Date(),
                weatherCondition: weatherService.condition,
                temperature: averageTemperatureSoFar,
                quoteText: quote?.text ?? "",
                quoteBookTitle: quote?.bookTitle,
                quoteAuthor: quote?.author,
                drawingFileName: fileName
            )
            modelContext.insert(entry)
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
            conditionName: weatherService.backgroundCondition.displayLabel,
            backgroundColors: weatherService.condition.gradientHSB(isDay: weatherService.isDay),
            quoteInkColor: weatherService.condition.quoteInkRGB(isDay: weatherService.isDay),
            quoteText: quote?.text ?? "오늘의 문장을 준비 중이에요",
            quoteBookTitle: quote?.bookTitle,
            quoteAuthor: quote?.author,
            updatedAt: Date(),
            symbolName: weatherService.condition.symbolName,
            backgroundImageName: weatherService.backgroundCondition.imageName
        )
        SharedWeatherStore.save(snapshot)

        // Precompute a window of upcoming daily quotes (today + two weeks) so
        // the widget can flip to the correct quote at each midnight on its
        // own — the widget extension has no access to `QuoteService`, so this
        // is the only way it can advance day by day without the app running.
        let now = Date()
        var upcoming: [DatedQuote] = []
        for offset in 0...14 {
            let day = SharedWeatherStore.date(daysAhead: offset, from: now)
            guard let dayQuote = quoteService.quoteForToday(condition: weatherService.condition, date: day) else { continue }
            upcoming.append(
                DatedQuote(
                    dateKey: SharedWeatherStore.dayKey(day),
                    quoteText: dayQuote.text,
                    quoteBookTitle: dayQuote.bookTitle,
                    quoteAuthor: dayQuote.author
                )
            )
        }
        SharedWeatherStore.saveUpcomingQuotes(upcoming)

        let drawing = canvasView.drawing
        if !drawing.bounds.isEmpty {
            // PencilKit's pure black/white ink is "adaptive" and renders
            // according to whatever interface style is current at the
            // moment of rasterization — without forcing light mode here,
            // black ink drawn in the (also light-forced) canvas came out
            // white in the widget whenever the device was in Dark Mode.
            var image: UIImage!
            UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
                image = drawing.image(from: drawing.bounds, scale: 2)
            }
            SharedDrawingStore.save(image)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
