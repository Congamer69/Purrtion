import SwiftUI
import SwiftData
import UserNotifications

@main
struct PurrtionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var goals = Goals()
    @AppStorage("appearance") private var appearance = Appearance.system
    @AppStorage(ThemeSetting.accentKey) private var accentID = ""

    /// Shared so the nightly background analysis can use the same store.
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: FoodEntry.self, SavedFood.self, WaterLog.self, WeightLog.self, CustomFood.self, DayReview.self)
        } catch {
            fatalError("Datenbank konnte nicht geöffnet werden: \(error)")
        }
    }()

    init() {
        // A server config built into this app is kept in the settings, so builds without one stay connected.
        FirebaseConfig.persistBundled()
        BLSDatabase.shared.preload()
        SwissDatabase.shared.preload()
        RestaurantDatabase.shared.preload()
        AutoClose.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(goals)
                .tint(Theme.accentText)
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(Self.container)
    }
}

/// The four ways to log food, always one tap away. Expanded: four buttons above the tab bar.
/// Inline (tab bar minimized while scrolling down): just "Suchen".
struct QuickAddAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        if placement == .inline {
            button("magnifyingglass", "Suchen", .search)
                .frame(maxWidth: .infinity)
        } else {
            HStack(spacing: 0) {
                button("magnifyingglass", "Suchen", .search)
                button("barcode.viewfinder", "Barcode", .barcode)
                button("camera.fill", "Foto", .photo)
                button("bolt.fill", "Schnell", .quick)
            }
        }
    }

    private func button(_ icon: String, _ title: String, _ sheet: AddSheet) -> some View {
        Button {
            Haptics.tap()
            AddRouter.shared.open(sheet)
        } label: {
            // Primary-colour text on the glass reads best; the accent stays on the icon.
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.accentText)
                Text(title).font(Theme.font(14, .bold)).foregroundStyle(Theme.textPrimary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct RootView: View {
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true
    @State private var appBuilt = false
    #if DEBUG
    @State private var debugAppearance = false
    #endif
    @State private var splashExit = false
    @State private var tab = 0
    @AppStorage("startTab") private var startTab = 0
    @ObservedObject private var router = NotificationRouter.shared
    @AppStorage(FriendsStore.enabledKey) private var friendsEnabled = true
    // Look & feel (Profil → Darstellung): screens are re-created with the new theme when one of these changes.
    @AppStorage(ThemeSetting.accentKey) private var themeAccent = ""
    @AppStorage(ThemeSetting.cornersKey) private var themeCorners = ""
    @AppStorage(ThemeSetting.cardsKey) private var themeCards = ""
    @AppStorage(ThemeSetting.backgroundKey) private var themeBackground = ""
    @AppStorage(ThemeSetting.fontKey) private var themeFont = ""
    private var themeRevision: String { [themeAccent, themeCorners, themeCards, themeBackground, themeFont].joined(separator: "|") }
    /// Re-renders the tabs when a server code is pasted or the server is disconnected.
    @AppStorage(FirebaseConfig.storageKey) private var serverCode = ""
    @StateObject private var appUpdate = AppUpdateChecker.shared

    var body: some View {
        ZStack {
            // The tabs are built only once the splash has played, so their setup can't make the intro stutter.
            if appBuilt {
            TabView(selection: $tab) {
                Tab("Heute", systemImage: "pawprint.fill", value: 0) { TodayView().id(themeRevision) }
                Tab("Verlauf", systemImage: "chart.bar.fill", value: 1) { StatsView().id(themeRevision) }
                if friendsEnabled && FirebaseConfig.isAvailable(serverCode) {
                    Tab("Freunde", systemImage: "person.2.fill", value: 3) { FriendsView().id(themeRevision) }
                }
                Tab("Profil", systemImage: "person.crop.circle.fill", value: 2) { SettingsView() }
            }
            // System behaviour: the tab bar shrinks while scrolling down and the accessory folds in next to it.
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewBottomAccessory(isEnabled: tab == 0) { QuickAddAccessory() }
            // No scaleEffect: scaling the UIKit tab bar while it is still laying out made it jump into place.
            .opacity(showSplash ? 0 : 1)
            .allowsHitTesting(!showSplash)
            }

            if showSplash {
                SplashView(exiting: splashExit)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            // Short, cute splash, long enough for the food database to finish loading.
            try? await Task.sleep(for: .milliseconds(700))
            tab = startTab
            appBuilt = true
            // Hidden under the splash while the tab bar, accessory and first screen lay out, so nothing moves after the reveal.
            try? await Task.sleep(for: .milliseconds(800))
            // The logo lifts away first, then the orange fades while the app settles in underneath.
            withAnimation(.easeIn(duration: 0.26)) { splashExit = true }
            try? await Task.sleep(for: .milliseconds(160))
            withAnimation(.smooth(duration: 0.6)) { showSplash = false }
            try? await Task.sleep(for: .milliseconds(500))
            router.appReady = true
            await appUpdate.checkOnLaunch()
            #if DEBUG
            if let t = UserDefaults.standard.string(forKey: "debugTab").flatMap(Int.init) { tab = t }
            if ProcessInfo.processInfo.arguments.contains("-debugAppearance") { debugAppearance = true }
            if ProcessInfo.processInfo.arguments.contains("-seedMeal") { seedDemoMeal() }
            if ProcessInfo.processInfo.arguments.contains("-demoData") { seedDemoData() }
            #endif
        }
        .sheet(isPresented: $appUpdate.showSheet) { AppUpdateSheet(checker: appUpdate) }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            WidgetBridge.update(ctx, goals: goals)
            Backup.autoBackupIfNeeded(ctx)
            Task { await HealthSync.importWeights(into: ctx) }
            if goals.activityEnabled {
                Task {
                    if await ActivityStore.refresh(days: 14) {
                        goals.activityUpdated()
                        WidgetBridge.update(ctx, goals: goals)
                    }
                }
            }
            AutoClose.schedule()
            // Catch up on changes made while Health sync was off or the app was killed mid-sync.
            Task { await NutritionSync.syncRecent(days: 3, container: PurrtionApp.container) }
            DatabaseUpdater.shared.autoUpdateIfNeeded()
            Task { await AutoClose.runIfNeeded(container: PurrtionApp.container) }
        }
        .onChange(of: router.reviewDay, initial: true) { _, day in
            // A tapped review notification always lands on "Heute".
            if day != nil { tab = 0 }
        }
        .onChange(of: scenePhase) { _, phase in
            // Back in the app: send pending friend changes and pick up answered requests.
            if phase == .active, friendsEnabled { Task { await FriendsStore.shared.refresh(ctx: ctx, goals: goals) } }
            if phase == .background {
                WidgetBridge.update(ctx, goals: goals)
                if friendsEnabled { FriendsStore.shared.uploadIfNeeded(ctx: ctx, goals: goals) }
            }
        }
        // New, changed or deleted entries reach friends a little later (debounced, only when the values changed).
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            if friendsEnabled { FriendsStore.shared.uploadSoon(ctx: ctx, goals: goals) }
        }
        // Invite links: purrtion://friend/CODE (opened from the invite page).
        .onOpenURL { url in
            guard FriendsStore.shared.handle(url: url) else { return }
            friendsEnabled = true
            tab = 3
        }
        .onChange(of: friendsEnabled) { _, on in if !on, tab == 3 { tab = 2 } }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            WidgetBridge.update(ctx, goals: goals)
        }
        #if DEBUG
        .sheet(isPresented: $debugAppearance) { NavigationStack { AppearanceSettingsView() } }
        #endif
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
        (try? ctx.fetch(FetchDescriptor<DayReview>()))?.forEach(ctx.delete)
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
        // Like a real photo scan: the AI only delivered macros (+ fibre) for each component.
        let lunch = [("Reis gekocht", 180.0), ("Lachs", 130), ("Brokkoli", 120), ("Avocado", 50)].compactMap { q, g -> RecipeIngredient? in
            guard var f = food(q) else { return nil }
            f.id = "ai-demo-\(q)"; f.source = .ai; f.origin = "KI-Schätzung · pro 100 g"
            f.per100.extra = f.per100.extra.filter { $0.key == "fiber" || $0.key == "sugar" }
            return RecipeIngredient(food: f, quantity: g, serving: .base(f.unit))
        }
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
        if ProcessInfo.processInfo.arguments.contains("-seedDrinks") {
            // Two drinks this evening + favourites and a recipe for "Was passt noch?".
            for (q, ml, minutesAgo) in [("Bier", 500.0, 150.0), ("Wein rot", 200, 60)] {
                if let f = food(q) {
                    let e = FoodEntry(food: f, quantity: ml, serving: .base(f.unit), day: today)
                    e.createdAt = .now.addingTimeInterval(-minutesAgo * 60)
                    ctx.insert(e)
                }
            }
            for (q, g) in [("Skyr", 250.0), ("Hähnchenbrust", 150), ("Banane", 120), ("Mandel", 30), ("Vollkornbrot", 100)] {
                if let f = food(q) {
                    let s = SavedFood(food: f); s.isFavorite = true; s.lastQuantity = g; s.lastServingName = f.unit
                    ctx.insert(s)
                }
            }
            let pasta = [("Spaghetti", 300.0), ("Tomate", 200), ("Parmesan", 30), ("Olivenöl", 15)].compactMap { ing($0.0, $0.1) }
            let existing = (try? ctx.fetch(FetchDescriptor<CustomFood>(predicate: #Predicate { $0.name == "Pasta Pomodoro" }))) ?? []
            existing.forEach(ctx.delete)
            ctx.insert(CustomFood(recipeName: "Pasta Pomodoro", ingredients: pasta, portions: 2))
        }
        try? ctx.save()
        WidgetBridge.update(ctx, goals: goals)
    }
}
#endif

struct SplashView: View {
    var exiting = false
    @AppStorage("catPalette") private var paletteID = CatPalette.ginger.id
    @AppStorage(ThemeSetting.accentKey) private var accentID = ""
    @Environment(\.colorScheme) private var scheme
    /// The system launch screen is always the default orange (or dark); the splash eases from it into the accent.
    @State private var tinted = false
    @State private var discIn = false
    @State private var catIn = false
    @State private var ring: CGFloat = 0
    @State private var lettersShown = 0

    private let word = Array("PURRTION")
    private var dark: Bool { scheme == .dark }
    /// Light: the accent fills the screen. Dark: the app's background setting (warm, neutral or black) with the accent on the details.
    private var launchColor: Color { dark ? Color(hex: 0x17151B) : Color(hex: 0xFF8A4A) }
    private var brand: Color { tinted ? (dark ? Theme.background : Theme.accent) : launchColor }
    /// Plate, ring and lettering.
    private var cream: Color { dark ? Theme.accent : Color(hex: 0xFFF3E4) }
    private var plate: Color { dark ? Theme.card : Color(hex: 0xFFF3E4) }
    private var ink: Color { dark ? Theme.accent : Color(hex: 0xFFF3E4) }

    var body: some View {
        ZStack {
            brand.ignoresSafeArea()

            VStack(spacing: 40) {
                ZStack {
                    Circle().fill(plate)
                        .frame(width: 184, height: 184)
                        .scaleEffect(discIn ? 1 : 0.05)
                        .shadow(color: (dark ? Color.black : Color(hex: 0xC4531C)).opacity(dark ? 0.5 : 0.22), radius: 18, y: 10)
                    Circle().trim(from: 0, to: ring)
                        .stroke(cream.opacity(0.9), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .frame(width: 216, height: 216)
                        .rotationEffect(.degrees(-90))
                    AnimatedSprite(frames: catIn ? CatMood.happy.frames : [Sprites.sit], fps: 4, pixel: 7,
                                   palette: CatPalette.byID(paletteID))
                        .offset(y: catIn ? -4 : -200)
                        .opacity(catIn ? 1 : 0)
                }
                .frame(height: 224)

                HStack(spacing: 5) {
                    ForEach(Array(word.enumerated()), id: \.offset) { i, ch in
                        PixelText(text: String(ch), pixel: 5, color: ink)
                            .offset(y: i < lettersShown ? 0 : 16)
                            .opacity(i < lettersShown ? 1 : 0)
                    }
                }
            }
            .scaleEffect(exiting ? 1.1 : 1)
            .opacity(exiting ? 0 : 1)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { tinted = true }
            play()
        }
    }

    private func play() {
        // 1. the plate eases in
        withAnimation(.spring(duration: 0.5, bounce: 0.2)) { discIn = true }
        // 2. the cat settles onto it
        withAnimation(.spring(duration: 0.6, bounce: 0.28).delay(0.14)) { catIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { Haptics.tap() }
        // 3. the ring draws around it while the letters rise in one after the other
        withAnimation(.easeInOut(duration: 0.95).delay(0.3)) { ring = 1 }
        for i in 0..<word.count {
            withAnimation(.easeOut(duration: 0.4).delay(0.45 + Double(i) * 0.045)) { lettersShown = i + 1 }
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
