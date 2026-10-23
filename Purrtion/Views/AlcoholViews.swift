import SwiftUI
import SwiftData
import Charts

/// Blood alcohol estimate of a day (drinks of that day; for today also the night before).
/// Secondary info – lives in the day overview behind the summary card.
struct AlcoholCard: View {
    let day: Date
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @Query private var entries: [FoodEntry]
    @Query(sort: \WeightLog.date, order: .reverse) private var weights: [WeightLog]
    @State private var editing = false

    init(day: Date) {
        let d = Calendar.current.startOfDay(for: day)
        self.day = d
        let prev = Calendar.current.date(byAdding: .day, value: -1, to: d)!
        _entries = Query(filter: #Predicate<FoodEntry> { $0.day == d || $0.day == prev }, sort: \FoodEntry.createdAt)
    }

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    /// Drinks of the day; yesterday's only count on today (they may still be in the blood).
    private var model: BloodAlcohol {
        let relevant = isToday ? entries : entries.filter { $0.day == day }
        return BloodAlcohol.make(entries: relevant, goals: goals, weight: weights.first?.kg)
    }

    static func hasDrinks(_ entries: [FoodEntry]) -> Bool { entries.contains { ($0.nutrients[.alcohol] ?? 0) >= 1 } }

    var body: some View {
        let m = model
        let now = Date()
        let current = isToday ? m.value(at: now) : 0
        let ownDrinks = m.drinks.filter { d in entries.first { $0.id == d.id }?.day == day }
        if !ownDrinks.isEmpty || current > 0 {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Promille", systemImage: "wineglass.fill").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if isToday {
                        Text(current.promilleString).font(Theme.font(17, .heavy))
                            .foregroundStyle(color(current))
                    } else if let peak = m.peak {
                        Text("max. \(peak.promille.promilleString)").font(Theme.font(15, .bold)).foregroundStyle(color(peak.promille))
                    }
                }
                chart(m, now: now)
                HStack(spacing: 14) {
                    if let peak = m.peak {
                        stat("Höchstwert", peak.promille.promilleString, peak.time.formatted(.dateTime.hour().minute()))
                    }
                    if isToday, current > 0 {
                        if let below = m.time(below: 0.5, after: now) {
                            stat("unter 0,5 ‰", "ab " + below.formatted(.dateTime.hour().minute()), nil)
                        }
                        if let sober = m.time(below: 0.01, after: now) {
                            stat("nüchtern", "ab " + sober.formatted(.dateTime.hour().minute()), nil)
                        }
                    }
                    stat("Alkohol", "\(Int(m.totalGrams.rounded())) g", "\(m.drinks.count) \(m.drinks.count == 1 ? "Getränk" : "Getränke")")
                }
                Button {
                    Haptics.tap()
                    withAnimation(Motion.quick) { editing.toggle() }
                } label: {
                    HStack {
                        Text("Getränke & Uhrzeiten").font(Theme.font(14, .semibold))
                        Spacer()
                        Image(systemName: "chevron.down").rotationEffect(.degrees(editing ? 180 : 0))
                    }
                    .foregroundStyle(Theme.accentText)
                }
                .buttonStyle(.plain)
                if editing {
                    VStack(spacing: 8) {
                        ForEach(m.drinks) { d in
                            if let entry = entries.first(where: { $0.id == d.id }) {
                                DrinkTimeRow(entry: entry, grams: d.grams, time: d.time)
                            }
                        }
                    }
                    .transition(.opacity)
                }
                Text("Schätzung nach Körperwasser (Watson) aus Geschlecht, Alter, Größe und Gewicht, Abbau 0,1 ‰ pro Stunde wie bei üblichen Promillerechnern. Tatsächliche Werte schwanken stark. Nicht geeignet, um die Fahrtüchtigkeit zu beurteilen.")
                    .font(Theme.font(11)).foregroundStyle(Theme.textSecondary)
            }
            .card()
        }
    }

    private func color(_ v: Double) -> Color { v >= 0.5 ? Theme.danger : v >= 0.3 ? Theme.carbs : Theme.textPrimary }

    private func stat(_ title: String, _ value: String, _ note: String?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(Theme.font(15, .bold)).foregroundStyle(Theme.textPrimary)
            Text(note.map { "\(title) · \($0)" } ?? title).font(Theme.font(11)).foregroundStyle(Theme.textSecondary)
        }
        .lineLimit(1).minimumScaleFactor(0.8)
    }

    @ViewBuilder
    private func chart(_ m: BloodAlcohol, now: Date) -> some View {
        let pts = m.points
        if let first = pts.first, let last = pts.last {
            Chart {
                ForEach(pts) { p in
                    AreaMark(x: .value("Zeit", p.time), y: .value("‰", p.promille))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.45), Theme.accent.opacity(0.05)],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Zeit", p.time), y: .value("‰", p.promille))
                        .foregroundStyle(Theme.accentText)
                        .interpolationMethod(.monotone)
                }
                RuleMark(y: .value("0,5 ‰", 0.5))
                    .foregroundStyle(Theme.danger.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                if isToday, now > first.time, now < last.time {
                    RuleMark(x: .value("Jetzt", now)).foregroundStyle(Theme.textSecondary.opacity(0.6))
                    PointMark(x: .value("Jetzt", now), y: .value("‰", m.value(at: now)))
                        .foregroundStyle(Theme.accentText).symbolSize(60)
                }
                ForEach(m.drinks) { d in
                    PointMark(x: .value("Getränk", d.time), y: .value("‰", 0))
                        .symbol { Image(systemName: "wineglass.fill").font(.system(size: 9)).foregroundStyle(Theme.textSecondary) }
                }
            }
            .chartYScale(domain: 0...max(0.6, (m.peak?.promille ?? 0) * 1.15))
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: max(1, Int(last.time.timeIntervalSince(first.time) / 3600 / 5)))) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .frame(height: 130)
        }
    }
}

/// One drink with an editable clock time (the time matters for the curve).
private struct DrinkTimeRow: View {
    let entry: FoodEntry
    let grams: Double
    @State var time: Date
    @Environment(\.modelContext) private var ctx

    init(entry: FoodEntry, grams: Double, time: Date) {
        self.entry = entry
        self.grams = grams
        _time = State(initialValue: time)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name).font(Theme.font(14, .semibold)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                Text("\(Int(grams.rounded())) g Alkohol").font(Theme.font(11)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute).labelsHidden()
                .onChange(of: time) { _, t in
                    entry.createdAt = QuickAddView.combine(day: entry.day, time: t)
                    try? ctx.save()
                }
        }
        .padding(10)
        .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
