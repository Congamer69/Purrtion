import WidgetKit
import SwiftUI
import AppIntents

@main
struct PurrtionWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        QuickAddWidget()
        LockScreenWidget()
    }
}

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        var s = WidgetSnapshot()
        s.kcal = 1240; s.protein = 80; s.carbs = 130; s.fat = 42; s.waterML = 1250; s.score = 78; s.entryCount = 4
        return SnapshotEntry(date: .now, snapshot: s)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load().forToday))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        // Refresh right after midnight so the widget starts the new day empty; the app reloads on every change.
        // The midnight entry must be computed for the new day, not for the moment the timeline is built.
        let snapshot = WidgetSnapshot.load()
        completion(Timeline(entries: [SnapshotEntry(date: now, snapshot: snapshot.values(on: now)),
                                      SnapshotEntry(date: midnight, snapshot: snapshot.values(on: midnight))],
                            policy: .after(midnight.addingTimeInterval(60))))
    }
}

// MARK: - Home screen widget (square + wide), configurable

enum SmallStyle: String, AppEnum {
    case cat, info
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Quadratisch"
    static var caseDisplayRepresentations: [SmallStyle: DisplayRepresentation] = [.cat: "Katze mit Ring", .info: "Mehr Infos"]
}

enum WideStyle: String, AppEnum {
    case bars, week
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Breit"
    static var caseDisplayRepresentations: [WideStyle: DisplayRepresentation] = [.bars: "Makros und Wasser", .week: "Woche"]
}

struct TodayConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Heute"
    static var description = IntentDescription("Wähle, was das Widget zeigt.")

    @Parameter(title: "Quadratisch", default: .cat) var small: SmallStyle
    @Parameter(title: "Breit", default: .bars) var wide: WideStyle
}

struct ConfiguredEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let small: SmallStyle
    let wide: WideStyle
}

struct TodayProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ConfiguredEntry {
        var s = WidgetSnapshot()
        s.kcal = 1240; s.protein = 80; s.carbs = 130; s.fat = 42; s.waterML = 1250; s.score = 78; s.entryCount = 4
        return ConfiguredEntry(date: .now, snapshot: s, small: .cat, wide: .bars)
    }

    func snapshot(for configuration: TodayConfigIntent, in context: Context) async -> ConfiguredEntry {
        if context.isPreview { return placeholder(in: context) }
        return ConfiguredEntry(date: .now, snapshot: WidgetSnapshot.load().forToday, small: configuration.small, wide: configuration.wide)
    }

    func timeline(for configuration: TodayConfigIntent, in context: Context) async -> Timeline<ConfiguredEntry> {
        let now = Date()
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        // The midnight entry is computed for the new day (with the goal of that day, without yesterday's activity bonus).
        let snapshot = WidgetSnapshot.load()
        return Timeline(entries: [ConfiguredEntry(date: now, snapshot: snapshot.values(on: now), small: configuration.small, wide: configuration.wide),
                                  ConfiguredEntry(date: midnight, snapshot: snapshot.values(on: midnight), small: configuration.small, wide: configuration.wide)],
                        policy: .after(midnight.addingTimeInterval(60)))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PurrtionToday", intent: TodayConfigIntent.self, provider: TodayProvider()) { entry in
            TodayWidgetView(s: entry.snapshot, small: entry.small, wide: entry.wide)
                .containerBackground(Theme.card, for: .widget)
        }
        .configurationDisplayName("Heute")
        .description("Deine Kalorien, Makros und dein Maskottchen auf einen Blick. Gedrückt halten und „Widget bearbeiten“ wählt die Darstellung.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

extension WidgetSnapshot {
    /// The accent chosen in the app.
    var accent: Color { Color(hex: accentHex ?? 0xFF8A4A) }
}

private func catSprite(for s: WidgetSnapshot) -> PixelSprite {
    if s.entryCount == 0 { return Sprites.sleep1 }
    if s.progress > 1.15 { return Sprites.stuffed1 }
    if s.progress > 1.05 { return Sprites.full }
    let proteinOK = s.protein >= s.proteinGoal * 0.9
    if s.progress >= 0.95 { return proteinOK ? Sprites.proud1 : Sprites.content2 }
    if s.progress >= 0.85 { return proteinOK ? Sprites.proud1 : Sprites.happy }
    return Sprites.sit
}

struct TodayWidgetView: View {
    let s: WidgetSnapshot
    var small: SmallStyle = .cat
    var wide: WideStyle = .bars
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    /// Tinted / clear home screen: iOS draws everything in one colour, so contrast has to come from opacity.
    private var mono: Bool { renderingMode != .fullColor }

    var body: some View {
        switch family {
        case .systemMedium: if wide == .week { weekView } else { medium }
        default: if small == .info { infoView } else { smallCat }
        }
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(mono ? Color.white.opacity(0.22) : s.accent.opacity(0.2), lineWidth: 9)
            Circle().trim(from: 0, to: min(s.progress, 1))
                .stroke(mono ? Color.white : (s.progress > 1.08 ? Theme.danger : s.accent), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            PixelSpriteView(sprite: catSprite(for: s), pixel: s.entryCount == 0 ? 2.6 : 3, palette: CatPalette.byID(s.paletteID), mono: mono)
        }
        .padding(4.5)
    }

    private var remainingText: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(abs(s.remaining).formatted(.number.precision(.fractionLength(0))))
                .font(Theme.font(26, .heavy))
                .foregroundStyle(mono ? Color.white : (s.remaining >= 0 ? Theme.textPrimary : Theme.danger))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .widgetAccentable()
            Text(s.remaining >= 0 ? "kcal übrig" : "kcal drüber")
                .font(Theme.font(12, .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var smallCat: some View {
        VStack(alignment: .leading, spacing: 6) {
            ring.frame(width: 84, height: 84).frame(maxWidth: .infinity)
            remainingText
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            ring.frame(width: 118, height: 118)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    remainingText
                    Spacer()
                    if let score = s.score {
                        VStack(spacing: 0) {
                            Text("\(score)").font(Theme.font(18, .heavy)).foregroundStyle(mono ? Color.white : Theme.fiber)
                                .widgetAccentable()
                            Text("Score").font(Theme.font(10, .semibold)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                bar("Protein", s.protein, s.proteinGoal, Theme.protein)
                bar("Kohlenh.", s.carbs, s.carbsGoal, Theme.carbs)
                bar("Fett", s.fat, s.fatGoal, Theme.fat)
                if s.waterEnabled {
                    bar("Wasser", Double(s.waterML) / 1000, Double(s.waterGoal) / 1000, Theme.water, unit: "l")
                }
            }
        }
    }

    // MARK: More info instead of the cat

    private var infoView: some View {
        VStack(alignment: .leading, spacing: 5) {
            remainingText
            HStack(spacing: 4) {
                Text("\(Int(s.kcal))").font(Theme.font(12, .bold)).foregroundStyle(mono ? Color.white : Theme.textPrimary)
                Text("von \(Int(s.kcalGoal)) kcal").font(Theme.font(12)).foregroundStyle(Theme.textSecondary).lineLimit(1).minimumScaleFactor(0.7)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(mono ? Color.white.opacity(0.22) : s.accent.opacity(0.2))
                    Capsule().fill(mono ? Color.white : (s.progress > 1.08 ? Theme.danger : s.accent))
                        .frame(width: max(5, geo.size.width * min(s.progress, 1))).widgetAccentable()
                }
            }
            .frame(height: 6)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                macroColumn("P", s.protein, s.proteinGoal, Theme.protein)
                macroColumn("K", s.carbs, s.carbsGoal, Theme.carbs)
                macroColumn("F", s.fat, s.fatGoal, Theme.fat)
            }
            if s.waterEnabled || s.score != nil {
                HStack {
                    if s.waterEnabled {
                        Label("\((Double(s.waterML) / 1000).formatted(.number.precision(.fractionLength(0...1)))) l", systemImage: "drop.fill")
                            .foregroundStyle(mono ? Color.white : Theme.water)
                    }
                    Spacer()
                    if let score = s.score {
                        Label("\(score)", systemImage: "heart.fill").foregroundStyle(mono ? Color.white : Theme.fiber)
                    }
                }
                .font(Theme.font(10, .bold))
                .widgetAccentable()
            }
        }
    }

    // MARK: Wide: the last seven days

    private func statusColor(_ kcal: Double, _ goal: Double) -> Color {
        if mono { return .white }
        if kcal <= 0 { return Theme.cardAlt }
        if kcal <= goal { return Theme.fiber }
        if kcal <= goal * 1.05 { return Color(hex: 0xFF9F43) }
        return Theme.danger
    }

    private var weekView: some View {
        let cal = Calendar.current
        let days: [WidgetSnapshot.DayPoint] = (0..<7).map { i in
            let d = cal.date(byAdding: .day, value: i - 6, to: s.day) ?? s.day
            if d == s.day { return .init(day: d, kcal: s.kcal, goal: s.kcalGoal) }
            return s.week?.first { $0.day == d } ?? .init(day: d, kcal: 0, goal: s.kcalGoal)
        }
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                remainingText
                Text("heute").font(Theme.font(10, .semibold)).foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
                if let score = s.score {
                    Label("\(score)", systemImage: "heart.fill").font(Theme.font(12, .bold)).foregroundStyle(mono ? Color.white : Theme.fiber)
                }
            }
            .frame(width: 96, alignment: .leading)
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(days, id: \.day) { p in
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            VStack {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(statusColor(p.kcal, p.goal).opacity(p.day == s.day ? 1 : 0.85))
                                    .frame(height: max(5, geo.size.height * min(p.kcal / max(p.goal, 1), 1.3) / 1.3))
                            }
                        }
                        Text(p.day.formatted(.dateTime.weekday(.narrow))).font(Theme.font(10, p.day == s.day ? .bold : .medium))
                            .foregroundStyle(p.day == s.day ? (mono ? Color.white : Theme.textPrimary) : Theme.textSecondary)
                    }
                }
            }
        }
        .widgetAccentable()
    }

    private func macroColumn(_ title: String, _ value: Double, _ goal: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(title) \(Int(value))").font(Theme.font(10, .bold)).foregroundStyle(mono ? Color.white : Theme.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(mono ? Color.white.opacity(0.22) : Theme.track(color))
                    Capsule().fill(mono ? Color.white : color).frame(width: max(3, geo.size.width * min(value / max(goal, 0.01), 1))).widgetAccentable()
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func bar(_ title: String, _ value: Double, _ goal: Double, _ color: Color, unit: String = "g") -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(Theme.font(10, .semibold)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(value.formatted(.number.precision(.fractionLength(0...1)))) / \(goal.formatted(.number.precision(.fractionLength(0...1)))) \(unit)")
                    .font(Theme.font(10, .medium)).foregroundStyle(Theme.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(mono ? Color.white.opacity(0.22) : Theme.track(color))
                    Capsule().fill(mono ? Color.white : color).frame(width: max(4, geo.size.width * min(value / max(goal, 0.01), 1)))
                        .widgetAccentable()
                }
            }
            .frame(height: 5)
        }
    }
}

// MARK: - Lock screen

struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrtionLockScreen", provider: SnapshotProvider()) { entry in
            LockScreenView(s: entry.snapshot)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Kalorien")
        .description("Übrige Kalorien auf dem Sperrbildschirm.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenView: View {
    let s: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    private var remaining: String { abs(s.remaining).formatted(.number.precision(.fractionLength(0))) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: min(s.progress, 1)) {
                Image(systemName: "pawprint.fill")
            } currentValueLabel: {
                Text(remaining).font(.system(size: 14, weight: .bold, design: .rounded)).minimumScaleFactor(0.5)
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            HStack(spacing: 8) {
                PixelSpriteView(sprite: catSprite(for: s), pixel: 2.4)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(remaining) kcal").font(.system(size: 17, weight: .heavy, design: .rounded))
                    Text(s.remaining >= 0 ? "übrig" : "drüber").font(.system(size: 12, weight: .medium, design: .rounded))
                    Text("P \(Int(s.protein)) · K \(Int(s.carbs)) · F \(Int(s.fat))")
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(.secondary)
                }
            }
        default:
            Text("🐾 \(remaining) kcal \(s.remaining >= 0 ? "übrig" : "drüber")")
        }
    }
}

// MARK: - Quick add (buttons)

/// Four ways to log food straight from the home screen, and water with one tap without opening the app.
struct QuickAddWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrtionQuickAdd", provider: SnapshotProvider()) { entry in
            QuickAddView(s: entry.snapshot)
                .containerBackground(Theme.card, for: .widget)
        }
        .configurationDisplayName("Schnell eintragen")
        .description("Suchen, Barcode, Foto und Schnell-Eintrag als Tasten. Im breiten Widget kommt Wasser mit einem Tipp dazu.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Wasser eintragen"
    static var description = IntentDescription("Trägt Wasser in Purrtion ein.")

    @Parameter(title: "Menge in ml") var ml: Int

    init() {}
    init(ml: Int) { self.ml = ml }

    func perform() async throws -> some IntentResult {
        WidgetSnapshot.addWater(ml)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct QuickAddView: View {
    let s: WidgetSnapshot
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    private var mono: Bool { renderingMode != .fullColor }

    private let buttons: [(icon: String, title: String, path: String)] = [
        ("magnifyingglass", "Suchen", "search"), ("barcode.viewfinder", "Barcode", "barcode"),
        ("camera.fill", "Foto", "photo"), ("bolt.fill", "Schnell", "quick"),
    ]

    private func tile(_ b: (icon: String, title: String, path: String)) -> some View {
        Link(destination: URL(string: "purrtion://add/\(b.path)")!) {
            VStack(spacing: 4) {
                Image(systemName: b.icon).font(.system(size: 20, weight: .bold)).foregroundStyle(mono ? Color.white : s.accent)
                Text(b.title).font(Theme.font(11, .bold)).foregroundStyle(mono ? Color.white : Theme.textPrimary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(mono ? Color.white.opacity(0.18) : s.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    var body: some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(abs(s.remaining).formatted(.number.precision(.fractionLength(0)))).font(Theme.font(28, .heavy))
                        .foregroundStyle(mono ? Color.white : (s.remaining >= 0 ? Theme.textPrimary : Theme.danger)).minimumScaleFactor(0.6).lineLimit(1)
                    Text(s.remaining >= 0 ? "kcal übrig" : "kcal drüber").font(Theme.font(12, .semibold)).foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 0)
                    if s.waterEnabled {
                        Button(intent: AddWaterIntent(ml: s.waterStep ?? 250)) {
                            Label("+\(s.waterStep ?? 250) ml", systemImage: "drop.fill").font(Theme.font(12, .bold))
                                .foregroundStyle(mono ? Color.white : Theme.water)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(mono ? Color.white.opacity(0.18) : Theme.water.opacity(0.15), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Text("\((Double(s.waterML) / 1000).formatted(.number.precision(.fractionLength(0...2)))) von \((Double(s.waterGoal) / 1000).formatted(.number.precision(.fractionLength(0...1)))) l")
                            .font(Theme.font(10, .semibold)).foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(width: 104, alignment: .leading)
                HStack(spacing: 8) { ForEach(buttons, id: \.path) { tile($0) } }
            }
        default:
            VStack(spacing: 8) {
                HStack(spacing: 8) { tile(buttons[0]); tile(buttons[1]) }
                HStack(spacing: 8) { tile(buttons[2]); tile(buttons[3]) }
            }
        }
    }
}
