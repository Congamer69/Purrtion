import SwiftUI
import SwiftData

/// Larger view behind the summary card: how the goal is made up, activity (incl. manual),
/// macros, water, score – and a share image of the day.
struct DayOverviewSheet: View {
    let day: Date
    @EnvironmentObject private var goals: Goals
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var entries: [FoodEntry]
    @Query private var water: [WaterLog]
    @Query private var reviews: [DayReview]
    @State private var manual: Double
    @State private var shareImages: [Image] = []
    @State private var shareIndex = 0

    init(day: Date) {
        self.day = Calendar.current.startOfDay(for: day)
        let d = self.day
        _entries = Query(filter: #Predicate<FoodEntry> { $0.day == d })
        _water = Query(filter: #Predicate<WaterLog> { $0.day == d })
        _reviews = Query(filter: #Predicate<DayReview> { $0.day == d })
        _manual = State(initialValue: ActivityStore.manual(for: d))
    }

    private var total: Nutrients { entries.reduce(Nutrients()) { $0 + $1.nutrients } }
    private var target: DayTarget { goals.target(for: day) }
    private var score: HealthScore? {
        guard goals.healthScoreEnabled, !entries.isEmpty else { return nil }
        return HealthScore(entries: entries, goalKcal: target.kcal, goalProtein: target.protein)
    }
    private var waterML: Int { water.reduce(0) { $0 + $1.ml } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    goalCard
                    AlcoholCard(day: day)
                    activityCard
                    macroCard
                    if let score { scoreRow(score) }
                    suggestionsLink
                    shareCard
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .presentationDetents([.large])
        .task {
            // Render after the sheet finished presenting so opening stays smooth.
            try? await Task.sleep(for: .milliseconds(400))
            renderShareImage()
        }
        .onChange(of: manual) { _, _ in renderShareImage() }
    }

    // MARK: Goal breakdown

    private var goalCard: some View {
        let remaining = target.kcal - total.kcal
        return VStack(spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    CalorieRing(progress: total.kcal / max(target.kcal, 1), lineWidth: 11)
                    VStack(spacing: 0) {
                        Text(abs(remaining).kcalString).font(Theme.font(24, .heavy)).foregroundStyle(remaining >= 0 ? Theme.textPrimary : Theme.danger)
                            .contentTransition(.numericText(value: remaining))
                        Text(remaining >= 0 ? "übrig" : "drüber").font(Theme.font(12, .medium)).foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(width: 112, height: 112)
                VStack(alignment: .leading, spacing: 7) {
                    line("Grundziel", target.baseKcal, note: goals.weekdayEnabled ? day.formatted(.dateTime.weekday(.wide)) : nil)
                    if target.activityBonus > 0 {
                        line("Aktivität", target.activityBonus, sign: "+", color: Theme.accent)
                    }
                    Divider()
                    line("Tagesziel", target.kcal, bold: true)
                    line("Gegessen", total.kcal, sign: "−")
                }
            }
        }
        .card()
        .animation(Motion.quick, value: target.kcal)
    }

    private func line(_ title: String, _ value: Double, sign: String = "", color: Color = Theme.textPrimary,
                      bold: Bool = false, note: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.font(14, bold ? .bold : .regular)).foregroundStyle(Theme.textSecondary)
            if let note { Text(note).font(Theme.font(11)).foregroundStyle(Theme.textSecondary.opacity(0.7)) }
            Spacer()
            Text("\(sign)\(value.kcalString) kcal").font(Theme.font(15, bold ? .heavy : .semibold)).foregroundStyle(color)
                .contentTransition(.numericText(value: value))
        }
    }

    // MARK: Activity

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Aktivität", systemImage: "flame.fill").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\((target.healthKcal + manual).kcalString) kcal").font(Theme.font(17, .heavy)).foregroundStyle(Theme.accent)
            }
            if goals.activityEnabled {
                HStack {
                    Text("Apple Health").font(Theme.font(14)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(target.healthKcal.kcalString) kcal · \(Int(target.activityPercent)) % angerechnet")
                        .font(Theme.font(13, .medium)).foregroundStyle(Theme.textSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Selbst eingetragen").font(Theme.font(14)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(manual.kcalString) kcal").font(Theme.font(15, .bold)).foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText(value: manual))
                }
                HStack(spacing: 8) {
                    ForEach([50.0, 100, 250, 500], id: \.self) { step in
                        Button { change(step) } label: {
                            Text("+\(Int(step))").font(Theme.font(14, .bold)).frame(maxWidth: .infinity).frame(height: 36)
                                .foregroundStyle(Theme.accent).background(Theme.accentSoft, in: Capsule())
                        }
                        .buttonStyle(SquishButtonStyle())
                    }
                    Button { change(-manual) } label: {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 36).foregroundStyle(Theme.textSecondary).background(Theme.cardAlt, in: Capsule())
                    }
                    .buttonStyle(SquishButtonStyle())
                    .disabled(manual == 0)
                }
            }
            Text(goals.activityEnabled
                 ? "Selbst eingetragene Aktivität (z. B. Training ohne Uhr) wird wie Apple Health zu \(Int(target.activityPercent)) % aufs Ziel angerechnet."
                 : "Selbst eingetragene Aktivität wird voll aufs Ziel angerechnet. Apple Health kannst du unter Einstellungen → Ziele verbinden.")
                .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
        }
        .card()
    }

    private func change(_ delta: Double) {
        Haptics.tap()
        withAnimation(Motion.quick) { manual = max(0, min(5000, manual + delta)) }
        ActivityStore.setManual(manual, for: day)
        goals.activityUpdated()
        WidgetBridge.update(ctx, goals: goals)
    }

    // MARK: Macros, score

    private var macroCard: some View {
        VStack(spacing: 12) {
            macro("Protein", total.protein, target.protein, Theme.protein)
            macro("Kohlenhydrate", total.carbs, target.carbs, Theme.carbs)
            macro("Fett", total.fat, target.fat, Theme.fat)
            if goals.waterEnabled {
                macro("Wasser", Double(waterML) / 1000, Double(goals.waterML) / 1000, Theme.water, unit: "l")
            }
        }
        .card()
    }

    private func macro(_ name: String, _ value: Double, _ goal: Double, _ color: Color, unit: String = "g") -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(name).font(Theme.font(14, .semibold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(value.formatted(.number.precision(.fractionLength(0...1)))) / \(goal.formatted(.number.precision(.fractionLength(0...1)))) \(unit)")
                    .font(Theme.font(13, .medium)).foregroundStyle(Theme.textSecondary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track(color))
                    Capsule().fill(color).frame(width: max(6, g.size.width * min(value / max(goal, 0.01), 1)))
                }
            }
            .frame(height: 8)
        }
    }

    private func scoreRow(_ score: HealthScore) -> some View {
        HStack(spacing: 14) {
            ScoreRing(value: Double(score.score) / 100, color: score.color, lineWidth: 6) {
                Text("\(score.score)").font(Theme.font(17, .heavy)).foregroundStyle(Theme.textPrimary)
            }
            .frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text("Health Score · \(score.rating)").font(Theme.font(15, .bold)).foregroundStyle(Theme.textPrimary)
                if let review = reviews.first {
                    Text("Tagesfazit: \(review.rating)").font(Theme.font(13)).foregroundStyle(review.color)
                }
            }
            Spacer()
        }
        .card(padding: 14)
    }

    // MARK: Suggestions

    private var suggestionsLink: some View {
        NavigationLink {
            SuggestionsList(day: day)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40).background(Theme.accentSoft, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Was passt noch?").font(Theme.font(15, .bold)).foregroundStyle(Theme.textPrimary)
                    Text("Favoriten & Rezepte für die restlichen \(max(0, target.kcal - total.kcal).kcalString) kcal")
                        .font(Theme.font(12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.textSecondary)
            }
            .card(padding: 14)
        }
        .buttonStyle(SquishButtonStyle())
    }

    // MARK: Share

    private var shareCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Teilen").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(ShareStyle.allCases[shareIndex].title).font(Theme.font(13, .semibold)).foregroundStyle(Theme.accent)
            }
            if shareImages.count == ShareStyle.allCases.count {
                TabView(selection: $shareIndex) {
                    ForEach(Array(shareImages.enumerated()), id: \.offset) { i, img in
                        img.resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                            .padding(.horizontal, 30).padding(.bottom, 34)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 520)
                let img = shareImages[shareIndex]
                ShareLink(item: img, preview: SharePreview("Mein Tag mit Purrtion", image: img)) {
                    Label("Teilen", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PillButtonStyle())
            } else {
                ProgressView().frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    @MainActor
    private func renderShareImage() {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -6, to: day)!
        let end = day
        let weekEntries = (try? ctx.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day >= start && $0.day <= end }))) ?? []
        let byDay = Dictionary(grouping: weekEntries, by: \.day)
        let week: [ShareData.DayBar] = (0..<7).map { i in
            let d = cal.date(byAdding: .day, value: i, to: start)!
            return ShareData.DayBar(day: d, kcal: (byDay[d] ?? []).reduce(0) { $0 + $1.kcal }, goal: goals.target(for: d).kcal)
        }
        var streak = 0
        var d = day
        while true {
            let dd = d
            let has = ((try? ctx.fetchCount(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day == dd }))) ?? 0) > 0
            guard has else { break }
            streak += 1
            d = cal.date(byAdding: .day, value: -1, to: d)!
            if streak > 999 { break }
        }
        let top = Dictionary(grouping: entries, by: \.name).map { ($0.key, $0.value.reduce(0) { $0 + $1.kcal }) }
            .sorted { $0.1 > $1.1 }.prefix(4).map { ShareData.Food(name: $0.0, kcal: $0.1) }
        let data = ShareData(day: day, total: total, target: target, activityPercent: target.activityPercent,
                             score: score, rating: reviews.first?.rating, ratingPoints: reviews.first?.points ?? [],
                             waterL: goals.waterEnabled ? Double(waterML) / 1000 : nil, waterGoalL: Double(goals.waterML) / 1000,
                             entries: entries.count, topFoods: Array(top), week: week, streak: streak,
                             palette: CatPalette.byID(UserDefaults.standard.string(forKey: "catPalette") ?? "ginger"))
        shareImages = ShareStyle.allCases.compactMap { style in
            let renderer = ImageRenderer(content: DayShareCard(style: style, data: data))
            renderer.scale = 3
            return renderer.uiImage.map { Image(uiImage: $0) }
        }
        shareIndex = min(shareIndex, max(shareImages.count - 1, 0))
    }
}

// MARK: - Share designs

enum ShareStyle: Int, CaseIterable {
    case ring, macros, score, week, story

    var title: String {
        switch self {
        case .ring: "Kalorien"
        case .macros: "Makros"
        case .score: "Health Score"
        case .week: "Woche"
        case .story: "Story"
        }
    }
}

struct ShareData {
    struct DayBar { let day: Date; let kcal: Double; let goal: Double }
    struct Food { let name: String; let kcal: Double }
    let day: Date
    let total: Nutrients
    let target: DayTarget
    let activityPercent: Double
    let score: HealthScore?
    let rating: String?
    let ratingPoints: [String]
    let waterL: Double?
    let waterGoalL: Double
    let entries: Int
    let topFoods: [Food]
    let week: [DayBar]
    let streak: Int
    let palette: CatPalette

    var progress: Double { total.kcal / max(target.kcal, 1) }
    var mood: CatMood { progress > 1.15 ? .stuffed : progress > 1.05 ? .full : progress >= 0.95 ? .content : progress >= 0.85 ? .happy : .idle }
}

/// Fixed-size images for WhatsApp, Instagram & co. Always in the dark look.
struct DayShareCard: View {
    let style: ShareStyle
    let data: ShareData

    static let bg = Color(hex: 0x17151B)
    static let card = Color(hex: 0x24212A)
    static let text = Color(hex: 0xF6F0EA)
    static let muted = Color(hex: 0x9E96A6)

    private func f(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font { .system(size: size, weight: w, design: .rounded) }

    var body: some View {
        VStack(spacing: 16) {
            header
            switch style {
            case .ring: ringBody
            case .macros: macrosBody
            case .score: scoreBody
            case .week: weekBody
            case .story: storyBody
            }
            Text("getrackt mit Purrtion 🐾").font(f(11, .semibold)).foregroundStyle(Self.muted)
        }
        .padding(24)
        .frame(width: 360, height: style == .story ? 640 : nil)
        .background(LinearGradient(colors: [Self.bg, gradientEnd], startPoint: .top, endPoint: .bottom))
        .environment(\.colorScheme, .dark)
    }

    private var gradientEnd: Color {
        switch style {
        case .ring, .story: Color(hex: 0x2A1E1A)
        case .macros: Color(hex: 0x1E1A2A)
        case .score: Color(hex: 0x182A1E)
        case .week: Color(hex: 0x1A222A)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PURRTION").font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(Theme.accent).tracking(2)
                Text(data.day.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(f(13, .medium)).foregroundStyle(Self.muted)
            }
            Spacer()
            if data.streak > 1 {
                Text("🔥 \(data.streak) Tage").font(f(13, .bold)).foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10).padding(.vertical, 5).background(Theme.accent.opacity(0.15), in: Capsule())
            }
        }
    }

    // Kalorien: ring with cat, macros, tiles
    @ViewBuilder private var ringBody: some View {
        ring(size: 210)
        HStack(spacing: 10) {
            macroTile("Protein", data.total.protein, data.target.protein, Theme.protein)
            macroTile("Kohlenh.", data.total.carbs, data.target.carbs, Theme.carbs)
            macroTile("Fett", data.total.fat, data.target.fat, Theme.fat)
        }
        HStack(spacing: 10) {
            if let score = data.score { tile("\(score.score)", "Health Score", Theme.fiber) }
            if data.target.activeKcal > 0 {
                tile("🔥 \(data.target.activeKcal.kcalString)", data.activityPercent > 0 ? "aktiv · \(Int(data.activityPercent)) % aufs Ziel" : "aktiv kcal", Theme.accent)
            }
            if let w = data.waterL, w > 0 { tile("\(w.formatted(.number.precision(.fractionLength(0...1)))) l", "Wasser", Theme.water) }
        }
        if let rating = data.rating { Text("„\(rating)“").font(f(18, .bold)).foregroundStyle(Self.text) }
    }

    private func ring(size: CGFloat) -> some View {
        ZStack {
            Circle().stroke(Theme.accent.opacity(0.18), lineWidth: size * 0.075)
            Circle().trim(from: 0, to: min(data.progress, 1))
                .stroke(data.progress > 1.08 ? Theme.danger : Theme.accent, style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                PixelSpriteView(sprite: data.mood.frames.first ?? Sprites.sit, pixel: size / 48, palette: data.palette)
                Text(data.total.kcal.kcalString).font(f(size * 0.16, .heavy)).foregroundStyle(Self.text)
                Text("von \(data.target.kcal.kcalString) kcal").font(f(13, .semibold)).foregroundStyle(Self.muted)
            }
        }
        .frame(width: size, height: size)
        .padding(.vertical, 4)
    }

    // Makros: donut split + top foods
    @ViewBuilder private var macrosBody: some View {
        let p = data.total.protein * 4, c = data.total.carbs * 4, fa = data.total.fat * 9
        let sum = max(p + c + fa, 1)
        HStack(spacing: 18) {
            ZStack {
                donut(from: 0, to: p / sum, Theme.protein)
                donut(from: p / sum, to: (p + c) / sum, Theme.carbs)
                donut(from: (p + c) / sum, to: 1, Theme.fat)
                VStack(spacing: 0) {
                    Text(data.total.kcal.kcalString).font(f(26, .heavy)).foregroundStyle(Self.text)
                    Text("kcal").font(f(12, .semibold)).foregroundStyle(Self.muted)
                }
            }
            .frame(width: 150, height: 150)
            VStack(alignment: .leading, spacing: 10) {
                split("Protein", data.total.protein, p / sum, Theme.protein)
                split("Kohlenhydrate", data.total.carbs, c / sum, Theme.carbs)
                split("Fett", data.total.fat, fa / sum, Theme.fat)
            }
        }
        if !data.topFoods.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Heute auf dem Teller").font(f(13, .bold)).foregroundStyle(Self.muted)
                ForEach(Array(data.topFoods.enumerated()), id: \.offset) { _, food in
                    HStack {
                        Text(food.name).font(f(15, .semibold)).foregroundStyle(Self.text).lineLimit(1)
                        Spacer()
                        Text("\(food.kcal.kcalString) kcal").font(f(14, .medium)).foregroundStyle(Self.muted)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Self.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func donut(from: Double, to: Double, _ color: Color) -> some View {
        Circle().trim(from: from + 0.006, to: max(from + 0.006, to - 0.006))
            .stroke(color, style: StrokeStyle(lineWidth: 18, lineCap: .butt))
            .rotationEffect(.degrees(-90))
    }

    private func split(_ name: String, _ g: Double, _ share: Double, _ color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text(name).font(f(12, .medium)).foregroundStyle(Self.muted)
                Text("\(Int(g.rounded())) g · \(Int((share * 100).rounded())) %").font(f(16, .bold)).foregroundStyle(Self.text)
            }
        }
    }

    // Health Score: big number + components
    @ViewBuilder private var scoreBody: some View {
        if let score = data.score {
            ZStack {
                Circle().stroke(score.color.opacity(0.18), lineWidth: 14)
                Circle().trim(from: 0, to: Double(score.score) / 100)
                    .stroke(score.color, style: StrokeStyle(lineWidth: 14, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(score.score)").font(f(54, .heavy)).foregroundStyle(Self.text)
                    Text(score.rating).font(f(15, .bold)).foregroundStyle(score.color)
                }
            }
            .frame(width: 170, height: 170)
            VStack(spacing: 9) {
                ForEach(score.components) { c in
                    HStack(spacing: 10) {
                        Text(c.title).font(f(12, .semibold)).foregroundStyle(Self.text).frame(width: 128, alignment: .leading).lineLimit(1)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(score.color.opacity(0.18))
                                Capsule().fill(score.color).frame(width: max(5, g.size.width * c.ratio))
                            }
                        }
                        .frame(height: 7)
                    }
                }
            }
            .padding(14)
            .background(Self.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            if let rating = data.rating { Text("„\(rating)“").font(f(17, .bold)).foregroundStyle(Self.text) }
        } else {
            ring(size: 200)
            Text("Health Score ist ausgeschaltet").font(f(13)).foregroundStyle(Self.muted)
        }
    }

    // Woche: 7 bars in goal colours
    @ViewBuilder private var weekBody: some View {
        let maxV = max(data.week.map { max($0.kcal, $0.goal) }.max() ?? 1, 1)
        let within = data.week.filter { $0.kcal > 0 && $0.kcal <= $0.goal }.count
        let logged = data.week.filter { $0.kcal > 0 }.count
        VStack(spacing: 4) {
            Text("\(within) von \(logged)").font(f(40, .heavy)).foregroundStyle(Self.text)
            Text("Tagen im Ziel").font(f(14, .semibold)).foregroundStyle(Self.muted)
        }
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(data.week.enumerated()), id: \.offset) { _, d in
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Self.card).frame(height: 170)
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(GoalStatus(kcal: d.kcal, goal: d.goal).color)
                            .frame(height: max(d.kcal > 0 ? 8 : 0, 170 * d.kcal / maxV))
                    }
                    Text(d.day.formatted(.dateTime.weekday(.narrow))).font(f(12, .bold))
                        .foregroundStyle(Calendar.current.isDate(d.day, inSameDayAs: data.day) ? Theme.accent : Self.muted)
                }
            }
        }
        .padding(14)
        .background(Self.card.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        let avg = logged == 0 ? 0 : data.week.reduce(0) { $0 + $1.kcal } / Double(logged)
        HStack(spacing: 10) {
            tile(avg.kcalString, "Ø kcal pro Tag", Theme.accent)
            if data.streak > 1 { tile("\(data.streak)", "Tage in Folge", Theme.fiber) }
        }
    }

    // Story: tall, big cat, one big number
    @ViewBuilder private var storyBody: some View {
        Spacer(minLength: 0)
        PixelSpriteView(sprite: data.mood.frames.first ?? Sprites.sit, pixel: 9, palette: data.palette)
        VStack(spacing: 2) {
            Text(data.total.kcal.kcalString).font(f(64, .heavy)).foregroundStyle(Self.text)
            Text("von \(data.target.kcal.kcalString) kcal").font(f(17, .semibold)).foregroundStyle(Self.muted)
        }
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.accent.opacity(0.18))
                Capsule().fill(data.progress > 1.08 ? Theme.danger : Theme.accent).frame(width: g.size.width * min(data.progress, 1))
            }
        }
        .frame(height: 12)
        .padding(.horizontal, 20)
        if let rating = data.rating {
            Text("„\(rating)“").font(f(24, .heavy)).foregroundStyle(Theme.accent)
        }
        if let point = data.ratingPoints.first {
            Text(point).font(f(14, .medium)).foregroundStyle(Self.muted).multilineTextAlignment(.center).padding(.horizontal, 10)
        }
        Spacer(minLength: 0)
        HStack(spacing: 10) {
            if let score = data.score { tile("\(score.score)", "Score", Theme.fiber) }
            tile("\(Int(data.total.protein.rounded())) g", "Protein", Theme.protein)
            if data.target.activeKcal > 0 { tile("🔥 \(data.target.activeKcal.kcalString)", "aktiv", Theme.accent) }
        }
    }

    private func macroTile(_ name: String, _ v: Double, _ goal: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name).font(f(11, .semibold)).foregroundStyle(Self.muted)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.2))
                    Capsule().fill(color).frame(width: max(5, g.size.width * min(v / max(goal, 1), 1)))
                }
            }
            .frame(height: 6)
            Text("\(Int(v.rounded())) g").font(f(15, .bold)).foregroundStyle(Self.text)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func tile(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(f(19, .heavy)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(f(11, .medium)).foregroundStyle(Self.muted).lineLimit(2).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10).padding(.horizontal, 4)
        .background(Self.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
