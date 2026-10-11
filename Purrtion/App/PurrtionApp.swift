import SwiftUI
import SwiftData

@main
struct PurrtionApp: App {
    @StateObject private var goals = Goals()
    @AppStorage("appearance") private var appearance = Appearance.system

    init() { BLSDatabase.shared.preload() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(goals)
                .tint(Theme.accent)
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(for: [FoodEntry.self, SavedFood.self, WaterLog.self, WeightLog.self, CustomFood.self, DayReview.self])
    }
}

struct RootView: View {
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true
    @State private var tab = 0

    var body: some View {
        ZStack {
            TabView(selection: $tab) {
                Tab("Heute", systemImage: "pawprint.fill", value: 0) { TodayView() }
                Tab("Verlauf", systemImage: "chart.bar.fill", value: 1) { StatsView() }
                Tab("Profil", systemImage: "person.crop.circle", value: 2) { SettingsView() }
            }
            .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashView()
                    .transition(.opacity.combined(with: .scale(scale: 1.15)))
                    .zIndex(1)
            }
        }
        .task {
            // Short, cute splash – just long enough for the food database to finish loading.
            try? await Task.sleep(for: .milliseconds(1300))
            withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-seedMeal") { seedDemoMeal() }
            if ProcessInfo.processInfo.arguments.contains("-demoData") { seedDemoData() }
            #endif
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            WidgetBridge.update(ctx, goals: goals)
            Backup.autoBackupIfNeeded(ctx)
            Task { await HealthSync.importWeights(into: ctx) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { WidgetBridge.update(ctx, goals: goals) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            WidgetBridge.update(ctx, goals: goals)
        }
        .fullScreenCover(isPresented: Binding(get: { !goals.onboarded && !showSplash }, set: { _ in })) {
            OnboardingView()
        }
    }
}

#if DEBUG
extension RootView {
    /// Simulator testing only: logs a 3-ingredient meal for today.
    func seedDemoMeal() {
        let db = BLSDatabase.shared
        let parts = ["Spaghetti", "Tomate", "Parmesan"].compactMap { db.search($0, limit: 1).first }
        let ingredients = zip(parts, [180.0, 120, 20]).map { RecipeIngredient(food: $0, quantity: $1, serving: .base($0.unit)) }
        ctx.insert(FoodEntry(mealName: "Spaghetti Pomodoro", ingredients: ingredients, source: .ai, day: .now))
        try? ctx.save()
    }

    /// README screenshots: replaces all entries with a realistic month of data.
    func seedDemoData() {
        (try? ctx.fetch(FetchDescriptor<FoodEntry>()))?.forEach(ctx.delete)
        (try? ctx.fetch(FetchDescriptor<WaterLog>()))?.forEach(ctx.delete)
        (try? ctx.fetch(FetchDescriptor<WeightLog>()))?.forEach(ctx.delete)
        try? ctx.save()
        let db = BLSDatabase.shared
        func food(_ q: String) -> FoodItem? { db.search(q, limit: 1).first }
        func ing(_ q: String, _ g: Double) -> RecipeIngredient? {
            food(q).map { RecipeIngredient(food: $0, quantity: g, serving: .base($0.unit)) }
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        // Today: two composite meals + single foods, ~85 % of the goal.
        for (q, g) in [("Gouda", 30.0), ("Vollkornbrot", 100), ("Apfel", 150), ("Banane", 120)] {
            if let f = food(q) { ctx.insert(FoodEntry(food: f, quantity: g, serving: .base(f.unit), day: today)) }
        }
        let bowl = [("Haferflocken", 60.0), ("Heidelbeere", 80), ("Joghurt", 150), ("Walnuss", 15)].compactMap { ing($0.0, $0.1) }
        let porridge = FoodEntry(mealName: "Porridge-Bowl", ingredients: bowl, source: .custom, day: today)
        porridge.createdAt = .now.addingTimeInterval(1)
        ctx.insert(porridge)
        let lunch = [("Reis gekocht", 180.0), ("Lachs", 130), ("Brokkoli", 120), ("Avocado", 50)].compactMap { ing($0.0, $0.1) }
        let salmon = FoodEntry(mealName: "Lachs-Bowl", ingredients: lunch, source: .ai, day: today)
        salmon.createdAt = .now.addingTimeInterval(2)
        ctx.insert(salmon)
        // A brand product with label values only – shows how "Tag abschließen" fills in the micronutrients.
        let bar = FoodItem(id: "demo-proteinbar", name: "Proteinriegel Schoko", brand: "Demo", source: .openFoodFacts,
                           per100: Nutrients(kcal: 380, protein: 33, carbs: 30, fat: 12, extra: ["sugar": 4, "fiber": 8, "salt": 0.5]),
                           servings: [ServingOption(name: "1 Riegel", grams: 55)])
        ctx.insert(FoodEntry(food: bar, quantity: 1, serving: bar.servings[0], day: today))
        ctx.insert(WaterLog(day: today, ml: 1500))

        // History: varied days – mostly within goal, some slightly / clearly over.
        let pools: [[(String, Double)]] = [
            [("Haferflocken", 70), ("Milch", 250), ("Hähnchenbrust", 150), ("Kartoffel", 300), ("Apfel", 150), ("Vollkornbrot", 80)],
            [("Müsli", 80), ("Joghurt", 200), ("Spaghetti", 200), ("Tomate", 150), ("Banane", 120), ("Käse", 40)],
            [("Vollkornbrot", 120), ("Ei", 120), ("Reis gekocht", 250), ("Linsen", 150), ("Birne", 150), ("Mandel", 30)],
        ]
        let factors: [Double] = [0.92, 0.97, 1.03, 0.88, 0.95, 1.15, 0.9, 0.99, 0.93, 1.04, 0.86, 0.96, 1.12, 0.94, 0.98, 0.91, 1.02, 0.95, 0.89, 0.97, 1.18, 0.93, 0.96, 0.9, 1.01, 0.94, 0.92]
        for (i, factor) in factors.enumerated() {
            let day = cal.date(byAdding: .day, value: -(i + 1), to: today)!
            let items = pools[i % pools.count].compactMap { q, g in food(q).map { ($0, g) } }
            let base = items.reduce(0) { $0 + $1.0.nutrients(grams: $1.1).kcal }
            let scale = goals.kcal * factor / max(base, 1)
            for (f, g) in items {
                ctx.insert(FoodEntry(food: f, quantity: (g * scale).rounded(), serving: .base(f.unit), day: day))
            }
            ctx.insert(WaterLog(day: day, ml: [1500, 2000, 2500, 1750][i % 4]))
        }
        for i in stride(from: 0, through: 28, by: 4) {
            ctx.insert(WeightLog(date: cal.date(byAdding: .day, value: -i, to: today)!, kg: 78.4 - Double(28 - i) * 0.05 + (i % 8 == 0 ? 0.2 : 0)))
        }
        try? ctx.save()
        WidgetBridge.update(ctx, goals: goals)
    }
}
#endif

struct SplashView: View {
    @AppStorage("catPalette") private var paletteID = CatPalette.ginger.id
    @State private var landed = false
    @State private var squash = false
    @State private var lettersShown = 0
    @State private var start = Date()

    private let word = Array("PURRTION")
    private let blocks = 14
    private let duration = 1.15

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            TwinklingStars()

            VStack(spacing: 26) {
                ZStack {
                    // soft pixel shadow that grows when the cat lands
                    Capsule().fill(Theme.textPrimary.opacity(0.08))
                        .frame(width: landed ? 110 : 30, height: 10)
                        .offset(y: 72)
                    AnimatedSprite(frames: landed ? CatMood.happy.frames : [Sprites.sit], fps: 4, pixel: 8,
                                   palette: CatPalette.byID(paletteID))
                        .scaleEffect(x: squash ? 1.15 : 1, y: squash ? 0.82 : 1, anchor: .bottom)
                        .offset(y: landed ? 0 : -420)
                }
                .frame(height: 140)

                HStack(spacing: 5) {
                    ForEach(Array(word.enumerated()), id: \.offset) { i, ch in
                        PixelText(text: String(ch), pixel: 5, color: Theme.accent)
                            .offset(y: i < lettersShown ? 0 : 26)
                            .scaleEffect(i < lettersShown ? 1 : 0.3)
                            .opacity(i < lettersShown ? 1 : 0)
                    }
                }

                TimelineView(.animation) { ctx in
                    let p = min(1, ctx.date.timeIntervalSince(start) / duration)
                    let barWidth: CGFloat = 196
                    let filled = Int((p * Double(blocks)).rounded(.down))
                    VStack(alignment: .leading, spacing: 4) {
                        PixelSpriteView(sprite: Int(ctx.date.timeIntervalSinceReferenceDate * 9) % 2 == 0 ? Sprites.walk1 : Sprites.walk2,
                                        pixel: 2, palette: CatPalette.byID(paletteID))
                            .offset(x: (barWidth - 40) * p)
                        HStack(spacing: 4) {
                            ForEach(0..<blocks, id: \.self) { i in
                                Rectangle()
                                    .fill(i < filled ? Theme.accent : Theme.line)
                                    .frame(width: 10, height: 10)
                                    .scaleEffect(i == filled - 1 ? 1.25 : 1)
                            }
                        }
                    }
                    .frame(width: barWidth, alignment: .leading)
                }
            }
        }
        .onAppear(perform: play)
    }

    private func play() {
        start = .now
        withAnimation(.interpolatingSpring(stiffness: 260, damping: 18)) { landed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.easeOut(duration: 0.08)) { squash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { squash = false }
            }
        }
        for i in 0..<word.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.06) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { lettersShown = i + 1 }
            }
        }
    }
}

/// Pixel stars that softly blink in the background.
struct TwinklingStars: View {
    private let spots: [(CGFloat, CGFloat, Double)] = [
        (0.12, 0.16, 0.0), (0.84, 0.12, 0.4), (0.22, 0.34, 0.9), (0.9, 0.36, 0.2), (0.08, 0.62, 0.6),
        (0.78, 0.66, 1.1), (0.3, 0.84, 0.3), (0.7, 0.88, 0.8), (0.5, 0.08, 0.5), (0.55, 0.95, 1.3),
    ]

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                ForEach(Array(spots.enumerated()), id: \.offset) { _, s in
                    let phase = (sin(t * 3 + s.2 * 4) + 1) / 2
                    PixelSpriteView(sprite: Sprites.star, pixel: 2)
                        .scaleEffect(0.6 + phase * 0.6)
                        .opacity(0.25 + phase * 0.6)
                        .position(x: geo.size.width * s.0, y: geo.size.height * s.1)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
