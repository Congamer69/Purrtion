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
    @State private var shareImage: Image?

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
                    activityCard
                    macroCard
                    if let score { scoreRow(score) }
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
        .animation(.snappy, value: target.kcal)
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
                    Text("\(target.healthKcal.kcalString) kcal · \(Int(goals.activityPercent)) % angerechnet")
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
                 ? "Selbst eingetragene Aktivität (z. B. Training ohne Uhr) wird immer voll aufs Ziel angerechnet."
                 : "Selbst eingetragene Aktivität wird voll aufs Ziel angerechnet. Apple Health kannst du unter Profil → Ziele verbinden.")
                .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
        }
        .card()
    }

    private func change(_ delta: Double) {
        Haptics.tap()
        withAnimation(.snappy) { manual = max(0, min(5000, manual + delta)) }
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

    // MARK: Share

    private var shareCard: some View {
        VStack(spacing: 12) {
            if let shareImage {
                shareImage.resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .frame(maxWidth: 260)
                ShareLink(item: shareImage, preview: SharePreview("Mein Tag mit Purrtion", image: shareImage)) {
                    Label("Tag teilen", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PillButtonStyle())
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    @MainActor
    private func renderShareImage() {
        let card = DayShareCard(day: day, total: total, target: target, score: score?.score,
                                rating: reviews.first?.rating, waterL: goals.waterEnabled ? Double(waterML) / 1000 : nil,
                                entries: entries.count,
                                palette: CatPalette.byID(UserDefaults.standard.string(forKey: "catPalette") ?? "ginger"))
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
    }
}

/// The image that gets shared (WhatsApp, Instagram …). Fixed size, always in the dark look.
struct DayShareCard: View {
    let day: Date
    let total: Nutrients
    let target: DayTarget
    let score: Int?
    let rating: String?
    let waterL: Double?
    let entries: Int
    let palette: CatPalette

    private let bg = Color(hex: 0x17151B)
    private let card = Color(hex: 0x24212A)
    private let text = Color(hex: 0xF6F0EA)
    private let muted = Color(hex: 0x9E96A6)

    private var progress: Double { total.kcal / max(target.kcal, 1) }
    private var mood: [PixelSprite] {
        if progress > 1.08 { return CatMood.full.frames }
        if progress >= 0.85 { return CatMood.happy.frames }
        return CatMood.idle.frames
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PURRTION").font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(Theme.accent).tracking(2)
                    Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(muted)
                }
                Spacer()
                PixelSpriteView(sprite: Sprites.paw, pixel: 2.5, palette: palette)
            }

            ZStack {
                Circle().stroke(Theme.accent.opacity(0.18), lineWidth: 16)
                Circle().trim(from: 0, to: min(progress, 1))
                    .stroke(progress > 1.08 ? Theme.danger : Theme.accent, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    PixelSpriteView(sprite: mood.first ?? Sprites.sit, pixel: 4.4, palette: palette)
                    Text(total.kcal.kcalString).font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundStyle(text)
                    Text("von \(target.kcal.kcalString) kcal").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(muted)
                }
            }
            .frame(width: 210, height: 210)
            .padding(.vertical, 4)

            HStack(spacing: 10) {
                macro("Protein", total.protein, target.protein, Theme.protein)
                macro("Kohlenh.", total.carbs, target.carbs, Theme.carbs)
                macro("Fett", total.fat, target.fat, Theme.fat)
            }

            HStack(spacing: 10) {
                if let score { tile("\(score)", "Health Score", Theme.fiber) }
                if target.activeKcal > 0 { tile("🔥 \(target.activeKcal.kcalString)", "aktiv kcal", Theme.accent) }
                if let waterL, waterL > 0 { tile("\(waterL.formatted(.number.precision(.fractionLength(0...1)))) l", "Wasser", Theme.water) }
                if score == nil && target.activeKcal == 0 && (waterL ?? 0) == 0 { tile("\(entries)", "Einträge", text) }
            }

            if let rating {
                Text("„\(rating)“").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(text)
            }

            Text("getrackt mit Purrtion 🐾").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(muted)
        }
        .padding(24)
        .frame(width: 360)
        .background(
            LinearGradient(colors: [bg, Color(hex: 0x2A1E1A)], startPoint: .top, endPoint: .bottom)
        )
        .environment(\.colorScheme, .dark)
    }

    private func macro(_ name: String, _ v: Double, _ goal: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(muted)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.2))
                    Capsule().fill(color).frame(width: max(5, g.size.width * min(v / max(goal, 1), 1)))
                }
            }
            .frame(height: 6)
            Text("\(Int(v.rounded())) g").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(text)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func tile(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 19, weight: .heavy, design: .rounded)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
