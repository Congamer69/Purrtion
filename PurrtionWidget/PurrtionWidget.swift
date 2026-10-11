import WidgetKit
import SwiftUI

@main
struct PurrtionWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
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

// MARK: - Home screen widget (square + wide)

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PurrtionToday", provider: SnapshotProvider()) { entry in
            TodayWidgetView(s: entry.snapshot)
                .containerBackground(Theme.card, for: .widget)
        }
        .configurationDisplayName("Heute")
        .description("Deine Kalorien, Makros und deine Katze auf einen Blick.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private func catSprite(for s: WidgetSnapshot) -> PixelSprite {
    if s.entryCount == 0 { return Sprites.sleep1 }
    if s.progress > 1.08 { return Sprites.full }
    if s.progress >= 0.85 { return Sprites.happy }
    return Sprites.sit
}

struct TodayWidgetView: View {
    let s: WidgetSnapshot
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    /// Tinted / clear home screen: iOS draws everything in one colour, so contrast has to come from opacity.
    private var mono: Bool { renderingMode != .fullColor }

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(mono ? Color.white.opacity(0.22) : Theme.accentSoft, lineWidth: 9)
            Circle().trim(from: 0, to: min(s.progress, 1))
                .stroke(mono ? Color.white : (s.progress > 1.08 ? Theme.danger : Theme.accent), style: StrokeStyle(lineWidth: 9, lineCap: .round))
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

    private var small: some View {
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
