import PencilKit
import SwiftData
import SwiftUI
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

                DrawingCanvasView(canvasView: $canvasView, isErasing: isErasing) { drawing in
                    saveTodayDrawing(drawing)
                }
                .ignoresSafeArea()

                weatherBadge
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                quoteCard
                    .padding(.bottom, 40)

                canvasControls
                    .padding(.trailing, 16)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showArchive = true
                    } label: {
                        Image(systemName: "book.closed")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        #if DEBUG
                        Button {
                            showAdminTool = true
                        } label: {
                            Image(systemName: "text.badge.plus")
                        }
                        #endif
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
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
            .onAppear {
                loadTodayDrawing()
                syncWidgets()
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

    private var weatherBadge: some View {
        HStack(spacing: 6) {
            Text(weatherService.condition.emoji(isDay: weatherService.isDay))
            if let temperature = weatherService.temperature {
                Text("\(Int(temperature.rounded()))°")
                    .font(.subheadline.weight(.semibold))
            }
            Text(weatherService.condition.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .animation(.easeInOut(duration: 0.6), value: weatherService.temperature)
    }

    private var quoteCard: some View {
        VStack(spacing: 6) {
            if let quote = todayQuote {
                Text(quote.text)
                    .font(.system(.body, design: .serif))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                if let source = quote.source {
                    Text("— \(source)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            } else {
                Text("문장을 준비 중이에요")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 24)
    }

    private var canvasControls: some View {
        VStack(spacing: 14) {
            Button {
                isErasing = false
            } label: {
                Image(systemName: "pencil")
                    .fontWeight(isErasing ? .regular : .bold)
            }
            Button {
                isErasing = true
            } label: {
                Image(systemName: "eraser")
                    .fontWeight(isErasing ? .bold : .regular)
            }
            Button {
                clearCanvas()
            } label: {
                Image(systemName: "trash")
            }
        }
        .font(.title3)
        .foregroundStyle(.white)
        .padding(10)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
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
            conditionName: weatherService.condition.displayName,
            backgroundColors: weatherService.condition.gradientHSB(isDay: weatherService.isDay),
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
