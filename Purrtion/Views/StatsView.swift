import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @State private var range = 7
    @Query(sort: \FoodEntry.day) private var entries: [FoodEntry]
    @Query(sort: \WeightLog.date) private var weights: [WeightLog]
    @State private var showWeight = false
    @State private var showWeightList = false
    @State private var month = Date()
    @State private var showMonth = false
    @State private var selectedDay: Date?

    struct DayStat: Identifiable {
        let day: Date
        let entries: [FoodEntry]
        let kcal, protein, carbs, fat: Double
        /// Goal that applied on that day.
        var goal: Double = 0
        var goalProtein: Double = 0
        /// Goal without the activity bonus (weekday goal).
        var baseGoal: Double = 0
        var active: Double = 0
        var bonus: Double = 0
        var id: Date { day }
    }

    private var cal: Calendar { Calendar.current }

    private var days: [DayStat] {
        if range == 7 { return currentWeek }
        let today = cal.startOfDay(for: .now)
        let start = cal.date(byAdding: .day, value: -(range - 1), to: today)!
        let grouped = Dictionary(grouping: entries.filter { $0.day >= start }, by: \.day)
        return (0..<range).map { i in
            let d = cal.date(byAdding: .day, value: i, to: start)!
            let es = grouped[d] ?? []
            return stat(d, es)
        }
    }

    /// Monday → Sunday of the current week (future days stay empty).
    private var currentWeek: [DayStat] {
        let mcal = Calendar.mondayFirst
        let monday = mcal.dateInterval(of: .weekOfYear, for: .now)!.start
        let grouped = Dictionary(grouping: entries.filter { $0.day >= monday }, by: \.day)
        return (0..<7).map { i in
            let d = mcal.date(byAdding: .day, value: i, to: monday)!
            let es = grouped[d] ?? []
            return stat(d, es)
        }
    }

    private func stat(_ d: Date, _ es: [FoodEntry]) -> DayStat {
        let t = goals.target(for: d)
        return DayStat(day: d, entries: es, kcal: es.reduce(0) { $0 + $1.kcal }, protein: es.reduce(0) { $0 + $1.protein },
                       carbs: es.reduce(0) { $0 + $1.carbs }, fat: es.reduce(0) { $0 + $1.fat }, goal: t.kcal, goalProtein: t.protein,
                       baseGoal: t.baseKcal, active: t.activeKcal, bonus: t.activityBonus)
    }

    private func avg(_ list: [DayStat], _ k: KeyPath<DayStat, Double>) -> Double {
        list.isEmpty ? 0 : list.reduce(0) { $0 + $1[keyPath: k] } / Double(list.count)
    }

    private var streak: Int {
        let set = Set(entries.map(\.day))
        var d = cal.startOfDay(for: .now)
        if !set.contains(d) { d = cal.date(byAdding: .day, value: -1, to: d)! }
        var n = 0
        while set.contains(d) { n += 1; d = cal.date(byAdding: .day, value: -1, to: d)! }
        return n
    }

    var body: some View {
        let all = days
        let logged = all.filter { $0.kcal > 0 }
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("Zeitraum", selection: $range) {
                        Text("Woche").tag(7)
                        Text("30 Tage").tag(30)
                        Text("90 Tage").tag(90)
                    }
                    .pickerStyle(.segmented)

                    overviewCard(logged)
                    goalCard(all)
                    kcalCard(all, logged)
                    if all.contains(where: { $0.active > 0 }) { activityCard(all) }
                    if goals.healthScoreEnabled { scoreCard(logged) }
                    macroCard(logged)
                    weekdayCard(logged)
                    topFoodsCard(logged)
                    microCard(logged)
                    weightCard
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Verlauf")
            .sheet(isPresented: $showWeight) { WeightSheet() }
            .sheet(isPresented: $showWeightList) { WeightListView() }
            .sheet(isPresented: $showMonth) {
                CalendarSheet(title: "Monatsübersicht") { picked in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { selectedDay = picked }
                }
            }
            .sheet(item: Binding(get: { selectedDay.map(IdentifiableDate.init) }, set: { selectedDay = $0?.date })) {
                DaySummarySheet(day: $0.date)
            }
            .task { await HealthSync.importWeights(into: ctx) }
        }
    }

    // MARK: Cards

    private func overviewCard(_ logged: [DayStat]) -> some View {
        let within = logged.filter { $0.kcal <= $0.goal }.count
        return HStack(spacing: 14) {
            CatMascot(mood: streak > 0 ? .happy : .sleeping, pixel: 3.5)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(streak) \(streak == 1 ? "Tag" : "Tage") in Folge").font(Theme.font(19, .bold)).foregroundStyle(Theme.textPrimary)
                HStack(spacing: 14) {
                    miniStat("\(within)/\(logged.count)", "im Ziel")
                    miniStat(logged.isEmpty ? "–" : "\(Int(Double(within) / Double(logged.count) * 100)) %", "Zieltreue")
                    miniStat("\(logged.count)", "Tage erfasst")
                }
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(Theme.font(16, .bold)).foregroundStyle(Theme.textPrimary)
            Text(label).font(Theme.font(11)).foregroundStyle(Theme.textSecondary)
        }
    }

    /// Goal tracking for exactly the selected range: week row, 30-day grid or 90-day heatmap.
    private func goalCard(_ all: [DayStat]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ziel eingehalten").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Button { showMonth = true } label: {
                    Label("Monat", systemImage: "calendar")
                        .font(Theme.font(13, .semibold)).foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Theme.accentSoft, in: Capsule())
                }
                .buttonStyle(SquishButtonStyle())
            }
            RangeGoalGrid(days: all, range: range) { selectedDay = $0 }
            GoalLegend()
        }
        .card()
    }

    private func kcalCard(_ all: [DayStat], _ logged: [DayStat]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Kalorien").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("Ø \(avg(logged, \.kcal).kcalString) kcal").font(Theme.font(15, .semibold)).foregroundStyle(Theme.accent)
            }
            Chart {
                ForEach(all) { d in
                    BarMark(x: .value("Tag", d.day, unit: .day), y: .value("kcal", d.kcal))
                        .foregroundStyle(GoalStatus(kcal: d.kcal, goal: d.goal).color)
                        .cornerRadius(range > 30 ? 1 : 5)
                }
                // Base goal of each day (weekday goals, earlier goals) as a stepped grey line …
                ForEach(all) { d in
                    LineMark(x: .value("Tag", d.day, unit: .day), y: .value("Ziel", d.baseGoal), series: .value("Serie", "Ziel"))
                        .interpolationMethod(.stepCenter)
                        .foregroundStyle(Theme.textSecondary)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
                // … and the activity bonus on top as an orange "flame" segment.
                ForEach(all.filter { $0.bonus > 0 }) { d in
                    RectangleMark(x: .value("Tag", d.day, unit: .day),
                                  yStart: .value("Ziel", d.baseGoal), yEnd: .value("Ziel+", d.goal),
                                  width: .ratio(range == 7 ? 0.28 : 0.5))
                        .foregroundStyle(Theme.accent)
                        .cornerRadius(2)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range == 7 ? 1 : range == 30 ? 7 : 30)) { _ in
                    AxisValueLabel(format: range == 7 ? .dateTime.weekday(.narrow) : .dateTime.day().month(.defaultDigits))
                }
            }
            .frame(height: 190)
            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Rectangle().fill(Theme.textSecondary).frame(width: 12, height: 2)
                    Text(goals.weekdayEnabled ? "Grundziel (je Wochentag)" : "Grundziel")
                }
                if all.contains(where: { $0.bonus > 0 }) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Theme.accent).frame(width: 5, height: 12)
                        Text("+ Aktivität")
                    }
                }
            }
            .font(Theme.font(11, .medium)).foregroundStyle(Theme.textSecondary)
            if !logged.isEmpty {
                let balance = logged.reduce(0) { $0 + ($1.kcal - $1.goal) }
                Text(balance <= 0 ? "Insgesamt \(abs(balance).kcalString) kcal unter dem Ziel (≈ \((abs(balance) / 7700).formatted(.number.precision(.fractionLength(1)))) kg Fett)."
                                  : "Insgesamt \(balance.kcalString) kcal über dem Ziel (≈ \((balance / 7700).formatted(.number.precision(.fractionLength(1)))) kg).")
                    .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
    }

    private func activityCard(_ all: [DayStat]) -> some View {
        let past = all.filter { $0.day <= cal.startOfDay(for: .now) }
        let active = past.filter { $0.active > 0 }
        let avgActive = active.isEmpty ? 0 : active.reduce(0) { $0 + $1.active } / Double(active.count)
        let credited = past.reduce(0) { $0 + $1.bonus }
        let net = past.filter { $0.kcal > 0 }
        let avgNet = net.isEmpty ? 0 : net.reduce(0) { $0 + ($1.kcal - $1.active) } / Double(net.count)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Aktivität", systemImage: "flame.fill").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("Ø \(avgActive.kcalString) kcal").font(Theme.font(15, .semibold)).foregroundStyle(Theme.accent)
            }
            Chart {
                ForEach(past) { d in
                    BarMark(x: .value("Tag", d.day, unit: .day), y: .value("aktiv", d.active))
                        .foregroundStyle(Theme.accent.opacity(0.35))
                        .cornerRadius(range > 30 ? 1 : 4)
                    // Overlay, not stacked: the credited part sits inside the activity bar.
                    if d.bonus > 0 {
                        RectangleMark(x: .value("Tag", d.day, unit: .day), yStart: .value("0", 0),
                                      yEnd: .value("angerechnet", min(d.bonus, d.active)), width: .ratio(0.6))
                            .foregroundStyle(Theme.accent)
                            .cornerRadius(range > 30 ? 1 : 4)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range == 7 ? 1 : range == 30 ? 7 : 30)) { _ in
                    AxisValueLabel(format: range == 7 ? .dateTime.weekday(.narrow) : .dateTime.day().month(.defaultDigits))
                }
            }
            .frame(height: 120)
            HStack(spacing: 14) {
                miniStat("\(past.reduce(0) { $0 + $1.active }.kcalString)", "aktiv gesamt")
                miniStat("\(credited.kcalString)", "aufs Ziel angerechnet")
                miniStat("\(avgNet.kcalString)", "Ø netto gegessen")
            }
            Text("Heller Balken = aktive Kalorien, kräftiger Teil = davon aufs Ziel angerechnet. Netto = gegessen minus aktiv.")
                .font(Theme.font(11)).foregroundStyle(Theme.textSecondary)
        }
        .card()
    }

    private func scoreCard(_ logged: [DayStat]) -> some View {
        let points: [(Date, Int)] = logged.map { d in
            (d.day, HealthScore(entries: d.entries, goalKcal: d.goal, goalProtein: d.goalProtein).score)
        }
        let average = points.isEmpty ? 0 : points.reduce(0) { $0 + $1.1 } / points.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Health Score").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("Ø \(average)").font(Theme.font(15, .semibold)).foregroundStyle(Theme.fiber)
            }
            if points.count >= 2 {
                Chart(points, id: \.0) { p in
                    AreaMark(x: .value("Tag", p.0, unit: .day), y: .value("Score", p.1))
                        .foregroundStyle(LinearGradient(colors: [Theme.fiber.opacity(0.35), Theme.fiber.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Tag", p.0, unit: .day), y: .value("Score", p.1))
                        .foregroundStyle(Theme.fiber).lineStyle(StrokeStyle(lineWidth: 3)).interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0...100)
                .frame(height: 140)
            } else {
                Text("Ab zwei erfassten Tagen siehst du hier deinen Verlauf.").font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
    }

    private func macroCard(_ logged: [DayStat]) -> some View {
        let p = avg(logged, \.protein), c = avg(logged, \.carbs), f = avg(logged, \.fat)
        let total = max(p * 4 + c * 4 + f * 9, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Ø Makros pro Tag").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
            HStack(spacing: 20) {
                Chart {
                    SectorMark(angle: .value("P", max(p * 4, 0.01)), innerRadius: .ratio(0.62), angularInset: 2).foregroundStyle(Theme.protein)
                    SectorMark(angle: .value("K", max(c * 4, 0.01)), innerRadius: .ratio(0.62), angularInset: 2).foregroundStyle(Theme.carbs)
                    SectorMark(angle: .value("F", max(f * 9, 0.01)), innerRadius: .ratio(0.62), angularInset: 2).foregroundStyle(Theme.fat)
                }
                .frame(width: 110, height: 110)
                .opacity(logged.isEmpty ? 0.2 : 1)
                VStack(alignment: .leading, spacing: 10) {
                    macroLine("Protein", p, goals.protein, p * 4 / total, Theme.protein)
                    macroLine("Kohlenhydrate", c, goals.carbs, c * 4 / total, Theme.carbs)
                    macroLine("Fett", f, goals.fat, f * 9 / total, Theme.fat)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func macroLine(_ name: String, _ v: Double, _ goal: Double, _ share: Double, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text(name).font(Theme.font(13, .medium)).foregroundStyle(Theme.textSecondary)
                Text("\(v.rounded().clean) / \(goal.clean) g · \(Int((share * 100).rounded())) %")
                    .font(Theme.font(14, .semibold)).foregroundStyle(Theme.textPrimary)
            }
        }
    }

    private func weekdayCard(_ logged: [DayStat]) -> some View {
        let cal = Calendar.mondayFirst
        let grouped = Dictionary(grouping: logged) { cal.component(.weekday, from: $0.day) }
        let order = (0..<7).map { (cal.firstWeekday - 1 + $0) % 7 + 1 }
        let data: [(String, Double, Double)] = order.map { wd in
            let list = grouped[wd] ?? []
            let avgKcal = list.isEmpty ? 0 : list.reduce(0) { $0 + $1.kcal } / Double(list.count)
            let avgGoal = list.isEmpty ? goals.kcal(forWeekday: wd) : list.reduce(0) { $0 + $1.goal } / Double(list.count)
            return (cal.shortWeekdaySymbols[wd - 1], avgKcal, avgGoal)
        }
        let top = data.max { $0.1 < $1.1 }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Wochentage").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                if let top, top.1 > 0 {
                    Text("Am meisten: \(top.0)").font(Theme.font(13, .semibold)).foregroundStyle(Theme.accent)
                }
            }
            Chart(data, id: \.0) { d in
                BarMark(x: .value("Tag", d.0), y: .value("kcal", d.1))
                    .foregroundStyle(GoalStatus(kcal: d.1, goal: d.2).color.opacity(0.85))
                    .cornerRadius(5)
                LineMark(x: .value("Tag", d.0), y: .value("Ziel", d.2), series: .value("Serie", "Ziel"))
                    .interpolationMethod(.stepCenter)
                    .foregroundStyle(Theme.textSecondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .frame(height: 130)
        }
        .card()
    }

    private func topFoodsCard(_ logged: [DayStat]) -> some View {
        let grouped = Dictionary(grouping: logged.flatMap(\.entries), by: \.name)
        let top = grouped.map { ($0.key, $0.value.reduce(0) { $0 + $1.kcal }, $0.value.count) }
            .sorted { $0.1 > $1.1 }.prefix(5)
        let total = max(logged.reduce(0) { $0 + $1.kcal }, 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Größte Kalorienquellen").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
            if top.isEmpty {
                Text("Noch keine Einträge im Zeitraum.").font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
            }
            ForEach(Array(top.enumerated()), id: \.offset) { i, item in
                HStack(spacing: 10) {
                    Text("\(i + 1)").font(Theme.font(13, .heavy)).foregroundStyle(Theme.accent).frame(width: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(item.0).font(Theme.font(14, .semibold)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                            Spacer()
                            Text("\(item.1.kcalString) kcal · \(item.2)×").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                        }
                        GeometryReader { g in
                            Capsule().fill(Theme.accent).frame(width: max(4, g.size.width * item.1 / total))
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func microCard(_ logged: [DayStat]) -> some View {
        let count = Double(max(logged.count, 1))
        let total = logged.flatMap(\.entries).reduce(Nutrients()) { $0 + $1.nutrients }
        let coverage: [(NutrientKey, Double)] = HealthScore.microKeys.compactMap { key in
            guard let dv = key.dailyValue else { return nil }
            return (key, (total[key] ?? 0) / count / dv)
        }
        .sorted { $0.1 < $1.1 }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Vitamine & Mineralstoffe").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("Ø pro Tag").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            }
            if logged.isEmpty {
                Text("Noch keine Daten im Zeitraum.").font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
            } else {
                Text("Am wenigsten abgedeckt").font(Theme.font(12, .semibold)).foregroundStyle(Theme.textSecondary)
                ForEach(coverage.prefix(5), id: \.0) { key, pct in
                    HStack {
                        Text(key.name).font(Theme.font(14)).foregroundStyle(Theme.textPrimary).frame(width: 110, alignment: .leading)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.cardAlt)
                                Capsule().fill(pct >= 1 ? Theme.fiber : pct >= 0.6 ? Theme.carbs : Theme.danger)
                                    .frame(width: max(4, g.size.width * min(pct, 1)))
                            }
                        }
                        .frame(height: 6)
                        Text("\(Int(pct * 100)) %").font(Theme.font(12, .semibold)).foregroundStyle(Theme.textSecondary).frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Gewicht").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                if HealthSync.isEnabled {
                    Image(systemName: "heart.fill").font(.system(size: 11)).foregroundStyle(Theme.protein)
                }
                Spacer()
                if let last = weights.last {
                    Text("\(last.kg, format: .number.precision(.fractionLength(1))) kg")
                        .font(Theme.font(15, .semibold)).foregroundStyle(Theme.accent)
                }
                Button { showWeight = true } label: {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 30, height: 30).background(Theme.accent, in: Circle())
                }
                .buttonStyle(SquishButtonStyle())
            }
            let shown = weights.filter { $0.date >= cal.date(byAdding: .day, value: -max(range, 30), to: .now)! }
            if shown.count >= 2 {
                let lo = (shown.map(\.kg).min() ?? 0) - 1, hi = (shown.map(\.kg).max() ?? 0) + 1
                Chart(shown) { w in
                    LineMark(x: .value("Datum", w.date), y: .value("kg", w.kg))
                        .interpolationMethod(.catmullRom).foregroundStyle(Theme.accent).lineStyle(StrokeStyle(lineWidth: 3))
                    PointMark(x: .value("Datum", w.date), y: .value("kg", w.kg)).foregroundStyle(Theme.accent).symbolSize(30)
                }
                .chartYScale(domain: lo...hi)
                .frame(height: 160)
                if let first = shown.first, let last = shown.last {
                    let diff = last.kg - first.kg
                    Text("\(diff <= 0 ? "−" : "+")\(abs(diff).formatted(.number.precision(.fractionLength(1)))) kg seit \(first.date.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(Theme.font(12)).foregroundStyle(diff <= 0 ? Theme.fiber : Theme.textSecondary)
                }
            } else {
                Text("Trag dein Gewicht regelmäßig ein oder verbinde Apple Health im Profil.")
                    .font(Theme.font(14)).foregroundStyle(Theme.textSecondary)
            }
            if !weights.isEmpty {
                Button { showWeightList = true } label: {
                    Label("Alle Einträge bearbeiten", systemImage: "list.bullet").font(Theme.font(14, .semibold))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct IdentifiableDate: Identifiable {
    let date: Date
    var id: Date { date }
}

struct WeightListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \WeightLog.date, order: .reverse) private var weights: [WeightLog]

    var body: some View {
        NavigationStack {
            List {
                ForEach(weights) { w in
                    HStack {
                        Text(w.date.formatted(date: .abbreviated, time: .omitted))
                        Spacer()
                        Text("\(w.kg, format: .number.precision(.fractionLength(1))) kg").font(Theme.font(16, .semibold))
                    }
                    .listRowBackground(Theme.card)
                }
                .onDelete { idx in
                    idx.map { weights[$0] }.forEach(ctx.delete)
                    try? ctx.save()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Gewicht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
        }
    }
}

struct WeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @EnvironmentObject private var goals: Goals
    @State private var kg: Double = 70
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                SliderField(title: "Gewicht", value: $kg, range: 35...200, step: 0.1, unit: "kg", decimals: 1)
                    .card()
                DatePicker("Datum", selection: $date, in: ...Date(), displayedComponents: .date)
                    .card()
                Spacer()
                Button("Speichern") {
                    let value = (kg * 10).rounded() / 10
                    ctx.insert(WeightLog(date: date, kg: value))
                    goals.weightKG = value
                    try? ctx.save()
                    HealthSync.save(kg: value, date: date)
                    Haptics.success()
                    dismiss()
                }
                .buttonStyle(PillButtonStyle())
            }
            .padding(20)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Gewicht eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
        .presentationDetents([.medium])
        .onAppear { kg = goals.weightKG }
    }
}

/// Coloured day cells for the selected range (7 → one week row, 30/90 → weekday-aligned grid).
struct RangeGoalGrid: View {
    let days: [StatsView.DayStat]
    let range: Int
    let onSelect: (Date) -> Void
    private var cal: Calendar { .mondayFirst }

    private func color(_ d: StatsView.DayStat) -> Color { GoalStatus(kcal: d.kcal, goal: d.goal).color }
    private func isFuture(_ d: StatsView.DayStat) -> Bool { d.day > cal.startOfDay(for: .now) }

    var body: some View {
        if range == 7 {
            HStack(spacing: 6) {
                ForEach(days) { d in
                    Button { if !isFuture(d) { Haptics.tap(); onSelect(d.day) } } label: {
                        VStack(spacing: 5) {
                            Text(d.day.formatted(.dateTime.weekday(.short)))
                                .font(Theme.font(11, .semibold)).foregroundStyle(Theme.textSecondary)
                            Text("\(cal.component(.day, from: d.day))")
                                .font(Theme.font(15, .bold))
                                .foregroundStyle(d.kcal > 0 ? .white : Theme.textPrimary)
                                .frame(maxWidth: .infinity).frame(height: 42)
                                .background(color(d), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(cal.isDateInToday(d.day) ? Theme.textPrimary : .clear, lineWidth: 2))
                            Text(d.kcal > 0 ? d.kcal.kcalString : "–")
                                .font(Theme.font(10, .medium)).foregroundStyle(Theme.textSecondary)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .opacity(isFuture(d) ? 0.4 : 1)
                    }
                    .buttonStyle(SquishButtonStyle())
                }
            }
        } else {
            let offset = ((cal.component(.weekday, from: days.first?.day ?? .now) - cal.firstWeekday) + 7) % 7
            let cells: [StatsView.DayStat?] = Array(repeating: nil, count: offset) + days.map { Optional($0) }
            let size: CGFloat = range == 30 ? 34 : 18
            let symbols = cal.veryShortStandaloneWeekdaySymbols
            let ordered = Array(symbols[(cal.firstWeekday - 1)...] + symbols[..<(cal.firstWeekday - 1)])
            VStack(spacing: 4) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: range == 30 ? 6 : 3), count: 7),
                          spacing: range == 30 ? 6 : 3) {
                    ForEach(Array(ordered.enumerated()), id: \.offset) { _, s in
                        Text(s).font(Theme.font(10, .semibold)).foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, d in
                        if let d {
                            Button { Haptics.tap(); onSelect(d.day) } label: {
                                RoundedRectangle(cornerRadius: range == 30 ? 8 : 4, style: .continuous)
                                    .fill(color(d))
                                    .frame(height: size)
                                    .overlay {
                                        if range == 30 {
                                            Text("\(cal.component(.day, from: d.day))")
                                                .font(Theme.font(12, .semibold))
                                                .foregroundStyle(d.kcal > 0 ? .white : Theme.textSecondary)
                                        }
                                    }
                                    .overlay(RoundedRectangle(cornerRadius: range == 30 ? 8 : 4, style: .continuous)
                                        .stroke(cal.isDateInToday(d.day) ? Theme.textPrimary : .clear, lineWidth: 2))
                            }
                            .buttonStyle(SquishButtonStyle())
                        } else {
                            Color.clear.frame(height: size)
                        }
                    }
                }
                if let first = days.first, let last = days.last {
                    HStack {
                        Text(first.day.formatted(.dateTime.day().month(.abbreviated)))
                        Spacer()
                        Text(last.day.formatted(.dateTime.day().month(.abbreviated)))
                    }
                    .font(Theme.font(11)).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}
